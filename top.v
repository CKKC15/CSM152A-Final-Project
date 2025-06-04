module top(
    input clk, //100 MHZ master clock
    input rst, // reset button
    input btn_roll, // when roll button is pressed
    input btn_stop, // to stop when wildcard
    input auto_roll_enable, // new switch input
    input balance_mode, //switch for balance mode
    input bet_mode, //switch for bet mode
    output [6:0] seg, // seven segment cathods
    output [3:0] an, // seven segment anodes
    input [3:0] rows,   // Pmod JB pins 10 to 7
    output [3:0] cols  // Pmod JB pins 4 to 1
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

//bet stuff
reg [15:0] bet_amount = 100;  //default 100
reg [15:0] bet_amount_store = 100;

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

wire [3:0] key;
reg bet_valid;
// keypad
keypad key_pad(
    .clk_100MHz(clk),
    .row(rows),
	.col(cols),
	.key_out(key)
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
        blink <= 0;
    end
end

always @(key) begin
    if (bet_mode) begin
        case (key)
            4'h1: bet_amount_store <= 100;
            4'h2: bet_amount_store <= 200;
            4'h3: bet_amount_store <= 300;
            4'h4: bet_amount_store <= 400; 
            4'h5: bet_amount_store <= 500;
            4'h6: bet_amount_store <= 600;
            4'h7: bet_amount_store <= 700;
            4'h8: bet_amount_store <= 800;
            4'h9: bet_amount_store <= 900;
        endcase
    end
end

always @(posedge clk) begin
    if (balance >= 1500) begin //first check for gameEnd conditions
        gameWin <= 1;
    end
    if (balance <= 500) begin
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
        if (bet_amount_store <= balance) begin
            // valid bet
            case (bet_amount_store)
                100: begin bet_amount <= 100; digit3 <= 4'd0; digit2 <= 4'd1; digit1 <= 4'd0; digit0 <= 4'd0; end
                200: begin bet_amount <= 200; digit3 <= 4'd0; digit2 <= 4'd2; digit1 <= 4'd0; digit0 <= 4'd0; end
                300: begin bet_amount <= 300; digit3 <= 4'd0; digit2 <= 4'd3; digit1 <= 4'd0; digit0 <= 4'd0; end
                400: begin bet_amount <= 400; digit3 <= 4'd0; digit2 <= 4'd4; digit1 <= 4'd0; digit0 <= 4'd0; end
                500: begin bet_amount <= 500; digit3 <= 4'd0; digit2 <= 4'd5; digit1 <= 4'd0; digit0 <= 4'd0; end
                600: begin bet_amount <= 600; digit3 <= 4'd0; digit2 <= 4'd6; digit1 <= 4'd0; digit0 <= 4'd0; end
                700: begin bet_amount <= 700; digit3 <= 4'd0; digit2 <= 4'd7; digit1 <= 4'd0; digit0 <= 4'd0; end
                800: begin bet_amount <= 800; digit3 <= 4'd0; digit2 <= 4'd8; digit1 <= 4'd0; digit0 <= 4'd0; end
                900: begin bet_amount <= 900; digit3 <= 4'd0; digit2 <= 4'd9; digit1 <= 4'd0; digit0 <= 4'd0; end
            endcase
        end else begin
            // invalid so display 0
            digit3 <= 4'd0;
            digit2 <= 4'd0;
            digit1 <= 4'd0;
            digit0 <= 4'd0;
            bet_amount <= 0;
        end
   
    end else begin
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
            isSpinning <= 1;
            timerDuration <= 300000000; //how long the spinning effect should last, i think around 3sec but mb change
            



        end else if (isSpinning && timerDuration < 1) begin //spinning stop, display actual numbers
            isSpinning <= 0;
            digit0 = rng0;
            digit1 = rng1;
            digit2 = rng2;
            digit3 = rng3;
            
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
            // no wildcards so check for winnings or losings
            else begin
                if (digit0 == digit1 && digit1 == digit2 && digit2 == digit3) begin
                    balance <= balance + (bet_amount * 15); //4 of the same
                end else if (
                    (digit0 == digit1 && digit1 == digit2) ||
                    (digit0 == digit1 && digit1 == digit3) ||
                    (digit0 == digit2 && digit2 == digit3) ||
                    (digit1 == digit2 && digit2 == digit3)
                ) begin
                    balance <= balance + (bet_amount * 7); //3 of the same
                end else if (
                    (digit0 == digit1) || (digit0 == digit2) || (digit0 == digit3) ||
                    (digit1 == digit2) || (digit1 == digit3) ||
                    (digit2 == digit3)
                ) begin
                    balance <= balance + (bet_amount * 2); //2 fo the same
                end else begin
                    balance <= balance - bet_amount; //nothing, lose money
                end
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
                    digit0 = (digit0 + 1) % 10;
                    slow_time0 <= 0;
                end
                2'd1: if (wildcard_mask[1] && slow_time1 >= 10000000) begin
                    digit1 = (digit1 + 1) % 10;
                    slow_time1 <= 0;
                end
                2'd2: if (wildcard_mask[2] && slow_time2 >= 10000000) begin
                    digit2 = (digit2 + 1) % 10;
                    slow_time2 <= 0;
                end
                2'd3: if (wildcard_mask[3] && slow_time3 >= 10000000) begin
                    digit3 = (digit3 + 1) % 10;
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
                    // done processing wildcards
                        if (digit0 == digit1 && digit1 == digit2 && digit2 == digit3) begin
                            balance <= balance + (bet_amount * 15); //4 of the same
                        end else if (
                            (digit0 == digit1 && digit1 == digit2) ||
                            (digit0 == digit1 && digit1 == digit3) ||
                            (digit0 == digit2 && digit2 == digit3) ||
                            (digit1 == digit2 && digit2 == digit3)
                        ) begin
                            balance <= balance + (bet_amount * 7); //3 of the same
                        end else if (
                            (digit0 == digit1) || (digit0 == digit2) || (digit0 == digit3) ||
                            (digit1 == digit2) || (digit1 == digit3) ||
                            (digit2 == digit3)
                        ) begin
                            balance <= balance + (bet_amount * 2); //2 fo the same
                        end else begin
                            balance <= balance - bet_amount; //nothing, lose money
                        end
        
                    end
                    processing_wildcard <= 0;
                end
            end
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