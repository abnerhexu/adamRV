`include "./AdamRiscv/define.vh"

module reg_status_table(
    input  wire        clk,
    input  wire        rst,
    // IS write: mark rd when instruction issues
    input  wire        is_write_en,
    input  wire[4:0]   is_rd,
    input  wire[2:0]   is_fu_id,
    // WB clear: clear rd when instruction writes back
    input  wire        wb_clear_en,
    input  wire[4:0]   wb_rd,
    input  wire[2:0]   wb_fu_id,
    // Query ports (combinational output)
    output wire[2:0]   status_0,  status_1,  status_2,  status_3,
    output wire[2:0]   status_4,  status_5,  status_6,  status_7,
    output wire[2:0]   status_8,  status_9,  status_10, status_11,
    output wire[2:0]   status_12, status_13, status_14, status_15,
    output wire[2:0]   status_16, status_17, status_18, status_19,
    output wire[2:0]   status_20, status_21, status_22, status_23,
    output wire[2:0]   status_24, status_25, status_26, status_27,
    output wire[2:0]   status_28, status_29, status_30, status_31
);

reg [2:0] status [0:31];

// Output assignments
assign status_0  = status[0];  assign status_1  = status[1];
assign status_2  = status[2];  assign status_3  = status[3];
assign status_4  = status[4];  assign status_5  = status[5];
assign status_6  = status[6];  assign status_7  = status[7];
assign status_8  = status[8];  assign status_9  = status[9];
assign status_10 = status[10]; assign status_11 = status[11];
assign status_12 = status[12]; assign status_13 = status[13];
assign status_14 = status[14]; assign status_15 = status[15];
assign status_16 = status[16]; assign status_17 = status[17];
assign status_18 = status[18]; assign status_19 = status[19];
assign status_20 = status[20]; assign status_21 = status[21];
assign status_22 = status[22]; assign status_23 = status[23];
assign status_24 = status[24]; assign status_25 = status[25];
assign status_26 = status[26]; assign status_27 = status[27];
assign status_28 = status[28]; assign status_29 = status[29];
assign status_30 = status[30]; assign status_31 = status[31];

integer i;
always @(posedge clk) begin
    if (!rst) begin
        for (i = 0; i < 32; i = i + 1)
            status[i] <= 3'b000;
    end
    else begin
        // WB clear: if the FU that marked this register is writing back, clear it
        if (wb_clear_en && wb_rd != 5'd0 && status[wb_rd] == wb_fu_id)
            status[wb_rd] <= 3'b000;
        // IS write: mark rd with the FU id (takes priority over WB clear on same reg)
        if (is_write_en)
            status[is_rd] <= is_fu_id;
    end
end

endmodule
