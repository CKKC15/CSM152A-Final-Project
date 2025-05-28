module top(
    input clk, //100 MHZ master clock
    input rst, // reset button
    input btn_roll, // when roll button is pressed
    output [6:0] seg, // seven segment cathods
    output [3:0] an // seven segment anodes
);

// Button edge detection
reg prev_btn = 0;
reg seeded = 0;
wire roll_edge = (~prev_btn & btn_roll);
wire seed_en = (roll_edge & ~seeded);

//these are used for the spinning part
reg [30:0] slow_time0 = 0; 
reg [30:0] slow_time1 = 0; 
reg [30:0] slow_time2 = 0; 
reg [30:0] slow_time3 = 0; 

//used to time the spinning portion
reg [30:0] timerDuration = 0;
reg isSpinning = 0;  //0 for not spinning, 1 for currently spinning

always @(posedge clk) begin
    prev_btn <= btn_roll;
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
    slow_time0 <= slow_time0 + 1;
    slow_time1 <= slow_time1 + 1;
    slow_time2 <= slow_time2 + 1;
    slow_time3 <= slow_time3 + 1;
    if (roll_edge && !isSpinning) begin //should trigger first time button is pressed
        isSpinning <= 1;
        timerDuration <= 300000000; //how long the spinning effect should last, i think around 3sec but mb change
    end else if (isSpinning && timerDuration < 1) begin //spinning stop, display actual numbers
        isSpinning <= 0;
        digit0 <= rng0;
        digit1 <= rng1;
        digit2 <= rng2;
        digit3 <= rng3;
    end else if (isSpinning) begin
        if (slow_time0 >= 30000000) begin //might need to change these numbers to get spinning effect to look good
            digit0 <= (digit0 + 1) % 10; //just need all 4 a bit different
            slow_time0 = 0;
        end
        if (slow_time1 >= 18000000) begin
            digit1 <= (digit1 + 1) % 10;
            slow_time1 = 0;
        end
        if (slow_time2 >= 42000000) begin
            digit2 <= (digit2 + 1) % 10;
            slow_time2 = 0;
        end
        if (slow_time3 >= 24000000) begin
            digit3 <= (digit3 + 1) % 10;
            slow_time3 = 0;
        end
        timerDuration <= timerDuration - 1; //1 unit spent spinning

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
    .seg(seg),
    .anode(an)
);

endmodule