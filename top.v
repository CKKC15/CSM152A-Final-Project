module top(
    input clk, //100 MHZ master clock
    input rst, // reset button
    input btn_roll, // when roll button is pressed
    input btn_stop, // to stop when wildcard
    input auto_roll_enable, // new switch input
    input balance_mode, //switch for balance mode
    input bet_mode, //switch for bet mode
    output [6:0] seg, // seven segment cathods
    output [3:0] an // seven segment anodes

);

// auto roll variables
reg [31:0] auto_roll_timer = 0;
wire auto_roll_ready = (auto_roll_timer >= 100000000); // 1 second
wire auto_roll_trigger = auto_roll_enable && auto_roll_ready && !isSpinning && !processing_wildcard;

// Button edge detection
reg prev_btn = 0;
wire roll_edge = (~prev_btn & btn_roll) || auto_roll_trigger;

reg seeded = 0;
wire seed_en = (roll_edge & ~seeded);

reg prev_stop = 0;
wire stop_edge = (~prev_stop & btn_stop);

//these are used for the spinning part
reg [30:0] slow_time0 = 0; 
reg [30:0] slow_time1 = 0; 
reg [30:0] slow_time2 = 0; 
reg [30:0] slow_time3 = 0; 

//used to time the spinning portion
reg [30:0] timerDuration = 0;
reg isSpinning = 0;  //0 for not spinning, 1 for currently spinning

//used for wildcard
reg [3:0] wildcard_mask = 4'b0000;  // 1 bit per digit of output
reg [3:0] next_mask;
reg [1:0] current_wildcard = 0;
reg processing_wildcard = 0; // boolean
reg waiting_before_wildcard = 0;
reg [31:0] wildcard_wait_counter = 0;

//balance amount
reg [15:0] balance = 1000; //start at 1000 dollars
reg [3:0] SAVEdigit0 = 0;
reg [3:0] SAVEdigit1 = 0;
reg [3:0] SAVEdigit2 = 0;
reg [3:0] SAVEdigit3 = 0;

//bet stuff
reg [15:0] bet = 100; //default bet amount at 100 dollars
reg gameStart = 1;

//game END statuses
reg gameWin = 0;
reg gameLoss = 0;
reg blink = 0; //blink for endgame
reg blinkCount = 0;


always @(posedge clk) begin
    prev_btn <= btn_roll;
    prev_stop <= btn_stop;
    if (seed_en)
        seeded <= 1;
end

//RNG outputs
wire [3:0] rng0, rng1, rng2, rng3;
rng rng_inst(
    .clk(clk),
    .rst(rst),
    .seed_en(seed_en),
    .d0(rng0),
    .d1(rng1),
    .d2(rng2),
    .d3(rng3)
);

// only update when button is pressed
reg [3:0] digit0 = 0, digit1 = 0, digit2 = 0, digit3 = 0;

always @(posedge clk) begin
    if (gameWin || gameLoss) begin
        blinkCount <= blinkCount + 1;
        if (blinkCount >= 12_500_500) begin
            blinkCount <= 0;
            blink <= ~blink;
        end
    end else begin
        blink <= 0
    end
end

always @(posedge clk) begin
    if (balance >= 9999) begin //first check for gameEnd conditions
        gameWin <= 1;
    end
    if (balance <= 0) begin
        gameLoss <= 1;
    end

    if (gameWin) begin //if win or lose, just stay at that state
        digit0 <= 9;
        digit1 <= 9;
        digit2 <= 9;
        digit3 <= 9;
    end else if (gameLoss) begin
        digit0 <= 0;
        digit1 <= 0;
        digit2 <= 0;
        digit3 <= 0;
    end else if (balance_mode) begin
        digit0 <= (balance % 10);
        digit1 <= (balance / 10) % 10;
        digit2 <= (balance / 100) % 10;
        digit3 <= (balance / 1000) % 10;
    end else if (bet_mode) begin
        //CODE HERE TO GET INPUT FOR bet
        //RIGHT NOW JUST INCREMENTS BY 100, should use pmod keypad to INPUT HERE

        //Need to make sure bet >= 1 and bet <= balance.
        bet <= bet + 100;
    end else begin
        digit0 <= SAVEdigit0; //restore state of digits if necessary (cuz of balance/bet)
        digit1 <= SAVEdigit1;
        digit2 <= SAVEdigit2;
        digit3 <= SAVEdigit3;

        slow_time0 <= slow_time0 + 1;
        slow_time1 <= slow_time1 + 1;
        slow_time2 <= slow_time2 + 1;
        slow_time3 <= slow_time3 + 1;
        
        
        if (!isSpinning && !processing_wildcard && auto_roll_enable) begin
            auto_roll_timer <= auto_roll_timer + 1;
        end else begin
            auto_roll_timer <= 0; // reset if rolling or wildcarding
        end
        
        if (roll_edge && !isSpinning && !processing_wildcard) begin //should trigger first time button is pressed
            if (!gameStart) begin //if game didn't just start, then we just finished getting 4 digits and should get results
                if (digit0 == digit1 && digit1 == digit2 && digit2 == digit3) begin
                    balance <= balance + (bet * 15); //4 of the same
                end else if (
                    (digit0 == digit1 && digit1 == digit2) ||
                    (digit0 == digit1 && digit1 == digit3) ||
                    (digit0 == digit2 && digit2 == digit3) ||
                    (digit1 == digit2 && digit2 == digit3)
                ) begin
                    balance <= balance + (bet * 7); //3 of the same
                end else if (
                    (digit0 == digit1) || (digit0 == digit2) || (digit0 == digit3) ||
                    (digit1 == digit2) || (digit1 == digit3) ||
                    (digit2 == digit3)
                ) begin
                    balance <= balance + (bet * 2); //2 fo the same
                end else begin
                    balance <= balance - bet; //nothing, lose money
                end

            end
            
            gameStart = 0;
            isSpinning <= 1;
            timerDuration <= 300000000; //how long the spinning effect should last, i think around 3sec but mb change
            



        end else if (isSpinning && timerDuration < 1) begin //spinning stop, display actual numbers
            isSpinning <= 0;
            digit0 <= rng0;
            digit1 <= rng1;
            digit2 <= rng2;
            digit3 <= rng3;
            
            next_mask = {
                (rng3 == 10),
                (rng2 == 10),
                (rng1 == 10),
                (rng0 == 10)
            };
            wildcard_mask <= next_mask;  // use next_mask for instant check and queue to wildcard nonblocking
            
            if (next_mask[3] || next_mask[2] || next_mask[1] || next_mask[0]) begin
                $display("Entering waiting wildcard phase!");
                waiting_before_wildcard <= 1;
                wildcard_wait_counter <= 0;
            end
        
        end else if (waiting_before_wildcard) begin
            wildcard_wait_counter <= wildcard_wait_counter + 1;
        
            // Wait for 0.5s = 100M cycles at 100 MHz
            if (wildcard_wait_counter >= 50000000) begin
                waiting_before_wildcard <= 0;
                processing_wildcard <= 1;
                $display("Entering wildcard phase after delay");
        
                // Choose first active wildcard
                if (wildcard_mask[0])
                    current_wildcard <= 0;
                else if (wildcard_mask[1])
                    current_wildcard <= 1;
                else if (wildcard_mask[2])
                    current_wildcard <= 2;
                else if (wildcard_mask[3])
                    current_wildcard <= 3;
            end
            
        end else if (isSpinning) begin
            if (slow_time0 >= 20000000) begin //might need to change these numbers to get spinning effect to look good
                digit0 <= (digit0 + 1) % 10; //just need all 4 a bit different
                slow_time0 <= 0;
            end
            if (slow_time1 >= 11000000) begin
                digit1 <= (digit1 + 1) % 10;
                slow_time1 <= 0;
            end
            if (slow_time2 >= 27000000) begin
                digit2 <= (digit2 + 1) % 10;
                slow_time2 <= 0;
            end
            if (slow_time3 >= 15000000) begin
                digit3 <= (digit3 + 1) % 10;
                slow_time3 <= 0;
            end
            timerDuration <= timerDuration - 1; //1 unit spent spinning
        
        // Handle wildcard digits one-by-one
        end else if (processing_wildcard) begin
            case (current_wildcard)
                2'd0: if (wildcard_mask[0] && slow_time0 >= 10000000) begin
                    digit0 <= (digit0 + 1) % 10;
                    slow_time0 <= 0;
                end
                2'd1: if (wildcard_mask[1] && slow_time1 >= 10000000) begin
                    digit1 <= (digit1 + 1) % 10;
                    slow_time1 <= 0;
                end
                2'd2: if (wildcard_mask[2] && slow_time2 >= 10000000) begin
                    digit2 <= (digit2 + 1) % 10;
                    slow_time2 <= 0;
                end
                2'd3: if (wildcard_mask[3] && slow_time3 >= 10000000) begin
                    digit3 <= (digit3 + 1) % 10;
                    slow_time3 <= 0;
                end
            endcase

            // when user presses stop button, lock in actual value
            if (stop_edge) begin
                $display("LOCKED IN VALUE");
                // clear wildcard bit
                wildcard_mask[current_wildcard] <= 0;
                
                // move to the next wildcard manually
                if (current_wildcard < 3 && wildcard_mask[current_wildcard + 1]) begin
                    current_wildcard <= current_wildcard + 1;
                end else if (current_wildcard < 2 && wildcard_mask[current_wildcard + 2]) begin
                    current_wildcard <= current_wildcard + 2;
                end else if (current_wildcard < 1 && wildcard_mask[current_wildcard + 3]) begin
                    current_wildcard <= current_wildcard + 3;
                end else begin
                    processing_wildcard <= 0;
                end
            end
        end

        SAVEdigit0 <= digit0; //save the state of current digits
        SAVEdigit1 <= digit1;
        SAVEdigit2 <= digit2;
        SAVEdigit3 <= digit3;

    end
    
end

// seven segment display
seven_segment seven_inst(
    .clk(clk),
    .rst(rst),
    .digit0(digit0),
    .digit1(digit1),
    .digit2(digit2),
    .digit3(digit3),
    .blink(blink),
    .seg(seg),
    .anode(an)
);

endmodule