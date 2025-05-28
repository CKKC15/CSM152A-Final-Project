module rng(
    input clk,
    input rst,
    input seed_en,
    output reg [3:0] d0, 
    output reg [3:0] d1, 
    output reg [3:0] d2, 
    output reg [3:0] d3
);

reg [15:0] lfsr = 16'hACE1;
reg seeded = 0;
reg [15:0] seed_counter = 0;

// Free running, generate seed based on user timing
always @(posedge clk or posedge rst) begin
    if (rst)
        seed_counter <= 0;
    else
        seed_counter <= seed_counter + 1;
end

// Seed the LSFR once on seed_end
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lfsr <= 16'hACE1;
        seeded <= 0;
    end else if (seed_en && !seeded) begin
        lfsr <= seed_counter;
        seeded <= 1;
    end else begin
        // advance the lfsr
        lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
    end
end

// generate the digits (0-9)
// also possibility of wildcard -> choose random 5-bit subset of lfsr, it has 2^5=32 possibilities, probability it is 0 is 1/32=~3% chance of wildcard
// for 4 digits, chance of at least 1 wildcard appearing is 1 - (1-1/32)^4 = ~12%
// we can change it to "<2" to double chance of wildcard appearing
always @(posedge clk) begin
    d0 <= ((lfsr[4:0] < 1) ? 10 : (lfsr[3:0] % 10));
    d1 <= ((lfsr[8:4] < 1) ? 10 : (lfsr[7:4] % 10));
    d2 <= ((lfsr[12:8] < 1) ? 10 : (lfsr[11:8] % 10));
    d3 <= ((lfsr[15:11] < 1) ? 10 : (lfsr[15:12] % 10));
end
endmodule