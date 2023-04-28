//Module: CPU
//Function: CPU is the top design of the RISC-V processor

//Inputs:
//	clk: main clock
//	arst_n: reset 
// enable: Starts the execution
//	addr_ext: Address for reading/writing content to Instruction Memory
//	wen_ext: Write enable for Instruction Memory
// ren_ext: Read enable for Instruction Memory
//	wdata_ext: Write word for Instruction Memory
//	addr_ext_2: Address for reading/writing content to Data Memory
//	wen_ext_2: Write enable for Data Memory
// ren_ext_2: Read enable for Data Memory
//	wdata_ext_2: Write word for Data Memory

// Outputs:
//	rdata_ext: Read data from Instruction Memory
//	rdata_ext_2: Read data from Data Memory



module cpu(
		input  wire			  clk,
		input  wire         arst_n,
		input  wire         enable,
		input  wire	[63:0]  addr_ext,
		input  wire         wen_ext,
		input  wire         ren_ext,
		input  wire [31:0]  wdata_ext,
		input  wire	[63:0]  addr_ext_2,
		input  wire         wen_ext_2,
		input  wire         ren_ext_2,
		input  wire [63:0]  wdata_ext_2,
		
		output wire	[31:0]  rdata_ext,
		output wire	[63:0]  rdata_ext_2

   );

// al die variables hernoemen
wire              zero_flag;
wire [      63:0] branch_pc,updated_pc,current_pc,jump_pc;
wire [      31:0] instruction;
wire [       1:0] alu_op_ID;
wire [       3:0] alu_control;
wire              reg_dst_ID,branch_ID,mem_read_ID,mem_2_reg_ID,
                  mem_write_ID,alu_src_ID, reg_write_ID, jump_ID;
wire [       4:0] regfile_waddr;
wire [      63:0] regfile_wdata_WB,mem_data_MEM,alu_out_EX,
                  regfile_rdata_1_ID,regfile_rdata_2_ID,
                  alu_operand_2;

wire signed [63:0] immediate_extended_ID;



// IF stage

pc #(
   .DATA_W(64)
) program_counter (
   .clk       (clk       ),
   .arst_n    (arst_n    ),
   .branch_pc (branch_pc ),
   .jump_pc   (jump_pc   ),
   .zero_flag (zero_flag ),
   .branch    (branch    ),
   .jump      (jump_ID      ),
   .current_pc(current_pc),
   .enable    (enable    ),
   .updated_pc(updated_pc)
);

sram_BW32 #(
   .ADDR_W(9 )
) instruction_memory(
   .clk      (clk           ),
   .addr     (current_pc    ),
   .wen      (1'b0          ),
   .ren      (1'b1          ),
   .wdata    (32'b0         ),
   .rdata    (instruction   ),
   .addr_ext (addr_ext      ),
   .wen_ext  (wen_ext       ), 
   .ren_ext  (ren_ext       ),
   .wdata_ext(wdata_ext     ),
   .rdata_ext(rdata_ext     )
);


// IF/ID

reg_arstn_en#(
   .DATA_W(32)
)signal_pipe_instruction_IF_ID(
   .clk     (clk),
   .arst_n  (arst_n),
   .din     (instruction),
   .en      (enable),
   .dout    (instruction_IF_ID)
);

reg_arstn_en#(
   .DATA_W(64)
)signal_pipe_PC_IF_ID(
   .clk     (clk),
   .arst_n  (arst_n),
   .din     (updated_pc),
   .en      (enable),
   .dout    (updated_pc_IF_ID)
);


// ID stage


control_unit control_unit(
   .opcode   (instruction_IF_ID[6:0]),
   .alu_op   (alu_op_ID),
   .reg_dst  (reg_dst_ID),
   .branch   (branch_ID),
   .mem_read (mem_read_ID),
   .mem_2_reg(mem_2_reg_ID),
   .mem_write(mem_write_ID),
   .alu_src  (alu_src_ID),
   .reg_write(reg_write_ID),
   .jump     (jump_ID)
);

register_file #(
   .DATA_W(64)
) register_file(
   .clk      (clk               ),
   .arst_n   (arst_n            ),
   .reg_write(reg_write_MEM_WB      ),    //output from MEM/WB
   .raddr_1  (instruction_IF_ID[19:15]),
   .raddr_2  (instruction_IF_ID[24:20]),
   .waddr    (instruction_MEM_WB[11:7] ), //output from MEM/WB
   .wdata    (regfile_wdata_WB     ),     //output from WB
   .rdata_1  (regfile_rdata_1_ID   ),
   .rdata_2  (regfile_rdata_2_ID   )
);

immediate_extend_unit immediate_extend_u(
    .instruction         (instruction_IF_ID),
    .immediate_extended  (immediate_extended_ID)
);

// ID/EX registers

reg_arstn_en#(
   .DATA_W(64)
)signal_pipe_regfile_rdata_1(
   .clk     (clk),
   .arst_n  (arst_n),
   .en      (enable),
   .din     (regfile_rdata_1_ID),
   .dout    (regfile_rdata_1_ID_EX)
);

reg_arstn_en#(
   .DATA_W(64)
)signal_pipe_regfile_rdata_2(
   .clk     (clk),
   .arst_n  (arst_n),
   .en      (enable),
   .din     (regfile_rdata_2_ID),
   .dout    (regfile_rdata_2_ID_EX)
);

//program counter
reg_arstn_en#(
   .DATA_W(64)
)signal_pipe_PC_ID_EX(
   .clk     (clk),
   .arst_n  (arst_n),
   .din     (updated_pc_ID),
   .en      (enable),
   .dout    (updated_pc_EX)
);

reg_arstn_en#(
   .DATA_W(2)
)signal_pipe_alu_op_ID_EX(
   .clk     (clk),
   .arst_n  (arst_n),
   .en      (enable),
   .din     (alu_op_ID),
   .dout    (alu_op_ID_EX)
);

reg_arstn_en#(
   .DATA_W(1)
)signal_pipe_reg_dst_ID_EX(
   .clk     (clk),
   .arst_n  (arst_n),
   .en      (enable),
   .din     (reg_dst_ID),
   .dout    (reg_dst_ID_EX)
);

reg_arstn_en#(
   .DATA_W(1)
)signal_pipe_branch_ID_EX(
   .clk     (clk),
   .arst_n  (arst_n),
   .en      (enable),
   .din     (branch_ID),
   .dout    (branch_ID_EX)
);

reg_arstn_en#(
   .DATA_W(1)
)signal_pipe_mem_read_ID_EX(
   .clk     (clk),
   .arst_n  (arst_n),
   .en      (enable),
   .din     (mem_read_ID),
   .dout    (mem_read_ID_EX)
);

reg_arstn_en#(
   .DATA_W(1)
)signal_pipe_mem_2_reg_ID_EX(
   .clk     (clk),
   .arst_n  (arst_n),
   .en      (enable),
   .din     (mem_2_reg_ID),
   .dout    (mem_2_reg_ID_EX)
);

reg_arstn_en#(
   .DATA_W(1)
)signal_pipe_mem_write_ID_EX(
   .clk     (clk),
   .arst_n  (arst_n),
   .en      (enable),
   .din     (mem_write_ID),
   .dout    (mem_write_ID_EX)
);

reg_arstn_en#(
   .DATA_W(1)
)signal_pipe_alu_src_ID_EX(
   .clk     (clk),
   .arst_n  (arst_n),
   .en      (enable),
   .din     (alu_src_ID),
   .dout    (alu_src_ID_EX)
);

reg_arstn_en#(
   .DATA_W(1)
)signal_pipe_reg_write_ID_EX(
   .clk     (clk),
   .arst_n  (arst_n),
   .en      (enable),
   .din     (reg_write_ID),
   .dout    (reg_write_ID_EX)
);

reg_arstn_en#(
   .DATA_W(1)
)signal_pipe_jump_ID_EX(
   .clk     (clk),
   .arst_n  (arst_n),
   .en      (enable),
   .din     (jump_ID),
   .dout    (jump_ID_EX)
);

reg_arstn_en#(
   .DATA_W(64)
)signal_pipe_imm_gen(
   .clk     (clk),
   .arst_n  (arst_n),
   .en      (enable),
   .din     (immediate_extended_ID),
   .dout    (immediate_extended_ID_EX)
);


reg_arstn_en#(
   .DATA_W(32)
)signal_pipe_instruction_ID_EX(
   .clk     (clk),
   .arst_n  (arst_n),
   .din     (instruction_IF_ID),
   .en      (enable),
   .dout    (instruction_ID_EX)
);

// EX stage


alu_control alu_ctrl(
   .func7_5       (instruction_ID_EX[30]   ),
   .func3          (instruction_ID_EX[14:12]),
   .alu_op         (alu_op_ID_EX),
   .alu_control    (alu_control)
);

mux_2 #(
   .DATA_W(64)
) alu_operand_mux (
   .input_a (immediate_extended_ID_EX), // forwarden
   .input_b (regfile_rdata_2_ID_EX   ),
   .select_a(alu_src_ID_EX           ),
   .mux_out (alu_operand_2     )
);

alu#(
   .DATA_W(16)
) alu(
   .alu_in_0 (regfile_rdata_1_ID_EX ),
   .alu_in_1 (alu_operand_2   ),
   .alu_ctrl (alu_control     ),
   .alu_out  (alu_out_EX      ),
   .zero_flag(zero_flag_EX    ),
   .overflow (                )
);



// EX/MEM

reg_arstn_en#(
   .DATA_W(64)
)signal_pipe_PC_EX_MEM(
   .clk     (clk),
   .arst_n  (arst_n),
   .din     (updated_pc_ID),
   .en      (enable),
   .dout    (updated_pc_EX)
);


reg_arstn_en#(
   .DATA_W(1)
)signal_pipe_reg_dst_EX_MEM(
   .clk     (clk),
   .arst_n  (arst_n),
   .en      (enable),
   .din     (reg_dst_ID_EX),
   .dout    (reg_dst_EX_MEM)
);

reg_arstn_en#(
   .DATA_W(1)
)signal_pipe_branch_EX_MEM(
   .clk     (clk),
   .arst_n  (arst_n),
   .en      (enable),
   .din     (branch_ID_EX),
   .dout    (branch_EX_MEM)
);

reg_arstn_en#(
   .DATA_W(1)
)signal_pipe_mem_read_EX_MEM(
   .clk     (clk),
   .arst_n  (arst_n),
   .en      (enable),
   .din     (mem_read_ID_EX),
   .dout    (mem_read_EX_MEM)
);

reg_arstn_en#(
   .DATA_W(1)
)signal_pipe_mem_2_reg_EX_MEM(
   .clk     (clk),
   .arst_n  (arst_n),
   .en      (enable),
   .din     (mem_2_reg_ID_EX),
   .dout    (mem_2_reg_EX_MEM)
);

reg_arstn_en#(
   .DATA_W(1)
)signal_pipe_mem_write_EX_MEM(
   .clk     (clk),
   .arst_n  (arst_n),
   .en      (enable),
   .din     (mem_write_ID_EX),
   .dout    (mem_write_EX_MEM)
);


reg_arstn_en#(
   .DATA_W(1)
)signal_pipe_reg_write_EX_MEM(
   .clk     (clk),
   .arst_n  (arst_n),
   .en      (enable),
   .din     (reg_write_ID_EX),
   .dout    (reg_write_EX_MEM)
);

reg_arstn_en#(
   .DATA_W(1)
)signal_pipe_jump_EX_MEM(
   .clk     (clk),
   .arst_n  (arst_n),
   .en      (enable),
   .din     (jump_ID_EX),
   .dout    (jump_EX_MEM)
);

reg_arstn_en#(
   .DATA_W(16)
)signal_pipe_alu_out(
   .clk     (clk),
   .arst_n  (arst_n),
   .en      (enable),
   .din     (alu_out_EX),
   .dout    (alu_out_EX_MEM)
);

reg_arstn_en#(
   .DATA_W(1)
)signal_pipe_zero_flag(
   .clk     (clk),
   .arst_n  (arst_n),
   .en      (enable),
   .din     (zero_flag_EX),
   .dout    (zero_flag_EX_MEM)
);

reg_arstn_en#(
   .DATA_W(64)
)signal_pipe_regfile_rdata_1_EX_MEM(
   .clk     (clk),
   .arst_n  (arst_n),
   .en      (enable),
   .din     (regfile_rdata_2_ID_EX),
   .dout    (regfile_rdata_2_EX_MEM)
);

reg_arstn_en#(
   .DATA_W(64)
)signal_pipe_instruction_EX_MEM(
   .clk     (clk),
   .arst_n  (arst_n),
   .en      (enable),
   .din     (instruction_ID_EX),
   .dout    (instruction_EX_MEM)
);

// updated pc forwarden
// immediate extended forwarden

// MEM stage

branch_unit#(
   .DATA_W(64)
)branch_unit(
   .updated_pc         (updated_pc        ), //fw
   .immediate_extended (immediate_extended), //fw
   .branch_pc          (branch_pc_MEM     ),
   .jump_pc            (jump_pc_MEM       )
);

sram_BW64 #(
   .ADDR_W(10)
) data_memory(
   .clk      (clk            ),
   .addr     (alu_out_EX_MEM ),
   .wen      (mem_write_EX_MEM),
   .ren      (mem_read_EX_MEM),
   .wdata    (regfile_rdata_2_EX_MEM),
   .rdata    (mem_data_MEM   ),   
   .addr_ext (addr_ext_2     ),
   .wen_ext  (wen_ext_2      ),
   .ren_ext  (ren_ext_2      ),
   .wdata_ext(wdata_ext_2    ),
   .rdata_ext(rdata_ext_2    )
);


// MEM/WB

reg_arstn_en#(
   .DATA_W(1)
)signal_pipe_reg_dst_MEM_WB(
   .clk     (clk),
   .arst_n  (arst_n),
   .en      (enable),
   .din     (reg_dst_EX_MEM),
   .dout    (reg_dst_MEM_WB)
);


reg_arstn_en#(
   .DATA_W(1)
)signal_pipe_mem_2_reg_MEM_WB(
   .clk     (clk),
   .arst_n  (arst_n),
   .en      (enable),
   .din     (mem_2_reg_EX_MEM),
   .dout    (mem_2_reg_MEM_WB)
);


reg_arstn_en#(
   .DATA_W(1)
)signal_pipe_reg_write_MEM_WB(
   .clk     (clk),
   .arst_n  (arst_n),
   .en      (enable),
   .din     (reg_write_EX_MEM),
   .dout    (reg_write_MEM_WB)
);


reg_arstn_en#(
   .DATA_W(16)
)signal_pipe_alu_out_MEM_WB(
   .clk     (clk),
   .arst_n  (arst_n),
   .en      (enable),
   .din     (alu_out_EX_MEM),
   .dout    (alu_out_MEM_WB)
);

reg_arstn_en#(
   .DATA_W(32)
)signal_pipe_mem_data(
   .clk     (clk),
   .arst_n  (arst_n),
   .en      (enable),
   .din     (mem_data_MEM),
   .dout    (mem_data_MEM_WB)
);

reg_arstn_en#(
   .DATA_W(32)
)signal_pipe_instruction_MEM_WB(
   .clk     (clk),
   .arst_n  (arst_n),
   .din     (instruction_EX_MEM),
   .en      (enable),
   .dout    (instruction_MEM_WB)
);


// WB stage

mux_2 #(
   .DATA_W(64)
) regfile_data_mux (
   .input_a  (mem_data_MEM_WB),
   .input_b  (alu_out_MEM_WB ),
   .select_a (mem_2_reg_MEM_WB),
   .mux_out  (regfile_wdata_WB)
);

endmodule


