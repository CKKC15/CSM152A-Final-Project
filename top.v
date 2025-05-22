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
    if (roll_edge) begin
        digit0 <= rng0;
        digit1 <= rng1;
        digit2 <= rng2;
        digit3 <= rng3;
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