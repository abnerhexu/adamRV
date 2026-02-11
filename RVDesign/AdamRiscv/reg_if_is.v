module reg_if_is(
    input wire clk,
    input wire rst,
    input wire[31:0] if_pc,
    input wire[31:0] if_inst,
    output reg[31:0] is_inst,
    output reg[31:0] is_pc,
    input  wire if_is_flush,
    input  wire if_is_stall
);

always @(posedge clk) begin
    if (!rst || if_is_flush) begin
        is_inst <= 32'b0;
        is_pc   <= 32'b0;
    end
    else if (if_is_stall) begin
        is_inst <= is_inst;
        is_pc   <= is_pc;
    end
    else begin
        is_inst <= if_inst;
        is_pc   <= if_pc;
    end
end

endmodule
