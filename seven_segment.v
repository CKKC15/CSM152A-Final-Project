module seven_segment(
    input clk,                   // 100MHz clock
    input rst,
    input [3:0] digit0, digit1, digit2, digit3,
    output reg [6:0] seg,        // Cathodes (a-g), active low
    output reg [3:0] anode       // Anodes (digit select), active low
);
    reg [19:0] refresh_counter = 0; // controls multiplexing rate
    wire [1:0] refresh_digit;       // selects which digit to show

    assign refresh_digit = refresh_counter[19:18]; // refresh rate ~381Hz

    always @(posedge clk or posedge rst) begin
        if (rst)
            refresh_counter <= 0;
        else
            refresh_counter <= refresh_counter + 1;
    end

    reg [3:0] current_bcd;

    always @(*) begin
        case (refresh_digit)
            2'b00: begin
                anode = 4'b1110;              // enable digit 0
                current_bcd = digit0;
            end
            2'b01: begin
                anode = 4'b1101;              // enable digit 1
                current_bcd = digit1;
            end
            2'b10: begin
                anode = 4'b1011;              // enable digit 2
                current_bcd = digit2;
            end
            2'b11: begin
                anode = 4'b0111;              // enable digit 3
                current_bcd = digit3;
            end
        endcase
    end

    always @(*) begin
        case (current_bcd)
            4'd0: seg = 7'b0000001;
            4'd1: seg = 7'b1001111;
            4'd2: seg = 7'b0010010;
            4'd3: seg = 7'b0000110;
            4'd4: seg = 7'b1001100;
            4'd5: seg = 7'b0100100;
            4'd6: seg = 7'b0100000;
            4'd7: seg = 7'b0001111;
            4'd8: seg = 7'b0000000;
            4'd9: seg = 7'b0000100;
            default: seg = 7'b1111111; // blank
        endcase
    end
endmodule

