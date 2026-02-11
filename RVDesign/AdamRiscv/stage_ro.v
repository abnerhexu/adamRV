module stage_ro(
    input  wire        clk,
    input  wire        rst,
    // Instruction info from FU status table
    input  wire[31:0]  ro_inst,
    input  wire[4:0]   ro_rs1,
    input  wire[4:0]   ro_rs2,
    // Register file write port (from WB)
    input  wire        w_regs_en,
    input  wire[4:0]   w_regs_addr,
    input  wire[31:0]  w_regs_data,
    // Outputs
    output wire[31:0]  ro_regs_data1,
    output wire[31:0]  ro_regs_data2,
    output wire[31:0]  ro_imm
);

// Register file: read rs1, rs2; write from WB
regs u_regs(
    .clk          (clk          ),
    .rst          (rst          ),
    .r_regs_addr1 (ro_rs1       ),
    .r_regs_addr2 (ro_rs2       ),
    .w_regs_addr  (w_regs_addr  ),
    .w_regs_data  (w_regs_data  ),
    .w_regs_en    (w_regs_en    ),
    .r_regs_o1    (ro_regs_data1),
    .r_regs_o2    (ro_regs_data2)
);

// Immediate generation
imm_gen u_imm_gen(
    .inst  (ro_inst),
    .imm_o (ro_imm )
);

endmodule
