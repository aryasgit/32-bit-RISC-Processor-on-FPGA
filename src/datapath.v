// ============================================================
//  32-bit MIPS RISC Processor - Datapath & Pipeline Stages
//  Author  : Shashwat
//  Role    : Datapath design, IF/ID + ID/EX stages,
//            Control unit, Register file, Hazard/Forwarding
//  Project : 5-Stage Pipelined MIPS on Artix-7 FPGA
//
//  Connects to teammate's modules:
//    <- instr_from_cache  (icache output)
//    <- stall             (icache stall)
//    <- clk, rst          (top-level)
//    -> branch_taken, branch_addr  (feeds back to pc module)
// ============================================================

// ============================================================
// 1. IF/ID PIPELINE REGISTER
// ============================================================
module if_id_reg (
    input  wire        clk,
    input  wire        rst,
    input  wire        stall,        // 1 = freeze (cache miss)
    input  wire        predictor_flush,        // 1 = insert NOP (branch taken)
    // Inputs from IF stage
    input  wire [31:0] if_pc_plus4,  // PC+4 of fetched instruction
    input  wire [31:0] if_instr,     // raw instruction word
    // Outputs to ID stage
    output reg  [31:0] id_pc_plus4,
    output reg  [31:0] id_instr
);
    always @(posedge clk) begin
        if (rst || predictor_flush) begin
            // NOP: all-zero instruction; safe for every decode field
            id_pc_plus4 <= 32'b0;
            id_instr    <= 32'b0;   // opcode=0,funct=0 -> decoded as NOP
        end else if (!stall) begin
            id_pc_plus4 <= if_pc_plus4;
            id_instr    <= if_instr;
        end
        // stall=1 and no flush: register holds its value (implicit)
    end
endmodule


// ============================================================
// 2. CONTROL UNIT
// ============================================================
module control_unit (
    input  wire [5:0] opcode,
    // EX-stage controls
    output reg        reg_dst,    // 0=rt is dest (I-type), 1=rd is dest (R-type)
    output reg        alu_src,    // 0=reg B, 1=sign-extended immediate
    output reg [1:0]  alu_op,     // ALU operation selector
    // MEM-stage controls
    output reg        mem_read,   // 1=load from data memory
    output reg        mem_write,  // 1=store to data memory
    output reg        branch,     // 1=conditional branch (beq)
    output reg        jump,       // 1=unconditional jump (j)
    // WB-stage controls
    output reg        mem_to_reg, // 0=ALU result, 1=memory data -> register
    output reg        reg_write   // 1=write result to register file
);
    // MIPS opcode constants
    localparam OP_RTYPE = 6'h00;  // R-type (add,sub,and,or,slt,sll,srl,jr)
    localparam OP_ADDI  = 6'h08;  // addi
    localparam OP_ADDIU = 6'h09;  // addiu
    localparam OP_SLTI  = 6'h0A;  // slti
    localparam OP_ANDI  = 6'h0C;  // andi
    localparam OP_ORI   = 6'h0D;  // ori
    localparam OP_LUI   = 6'h0F;  // lui
    localparam OP_LW    = 6'h23;  // lw
    localparam OP_SW    = 6'h2B;  // sw
    localparam OP_BEQ   = 6'h04;  // beq
    localparam OP_BNE   = 6'h05;  // bne
    localparam OP_J     = 6'h02;  // j
    localparam OP_JAL   = 6'h03;  // jal

    always @(*) begin
        // Safe defaults - everything off, prevents latch inference
        reg_dst    = 1'b0;
        alu_src    = 1'b0;
        alu_op     = 2'b00;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        branch     = 1'b0;
        jump       = 1'b0;
        mem_to_reg = 1'b0;
        reg_write  = 1'b0;

        case (opcode)
            OP_RTYPE: begin
                reg_dst    = 1'b1;   // destination = rd field
                alu_src    = 1'b0;   // second operand from register
                alu_op     = 2'b10;  // ALU control looks at funct
                mem_read   = 1'b0;
                mem_write  = 1'b0;
                branch     = 1'b0;
                mem_to_reg = 1'b0;   // result from ALU
                reg_write  = 1'b1;
            end
            OP_ADDI, OP_ADDIU: begin
                reg_dst    = 1'b0;
                alu_src    = 1'b1;   // immediate operand
                alu_op     = 2'b11;
                mem_to_reg = 1'b0;
                reg_write  = 1'b1;
            end
            OP_SLTI: begin
                reg_dst    = 1'b0;
                alu_src    = 1'b1;
                alu_op     = 2'b11;
                mem_to_reg = 1'b0;
                reg_write  = 1'b1;
            end
            OP_ANDI: begin
                reg_dst    = 1'b0;
                alu_src    = 1'b1;
                alu_op     = 2'b11;
                mem_to_reg = 1'b0;
                reg_write  = 1'b1;
            end
            OP_ORI: begin
                reg_dst    = 1'b0;
                alu_src    = 1'b1;
                alu_op     = 2'b11;
                mem_to_reg = 1'b0;
                reg_write  = 1'b1;
            end
            OP_LUI: begin
                reg_dst    = 1'b0;
                alu_src    = 1'b1;
                alu_op     = 2'b11;
                mem_to_reg = 1'b0;
                reg_write  = 1'b1;
            end
            OP_LW: begin
                reg_dst    = 1'b0;
                alu_src    = 1'b1;   // base + offset
                alu_op     = 2'b00;  // add
                mem_read   = 1'b1;
                mem_write  = 1'b0;
                branch     = 1'b0;
                mem_to_reg = 1'b1;   // result from memory
                reg_write  = 1'b1;
            end
            OP_SW: begin
                reg_dst    = 1'bx;   // don't care - no register write
                alu_src    = 1'b1;
                alu_op     = 2'b00;  // add
                mem_read   = 1'b0;
                mem_write  = 1'b1;
                branch     = 1'b0;
                mem_to_reg = 1'bx;
                reg_write  = 1'b0;
            end
            OP_BEQ: begin
                reg_dst    = 1'bx;
                alu_src    = 1'b0;
                alu_op     = 2'b01;  // subtract -> zero flag for compare
                mem_read   = 1'b0;
                mem_write  = 1'b0;
                branch     = 1'b1;
                mem_to_reg = 1'bx;
                reg_write  = 1'b0;
            end
            OP_BNE: begin
                reg_dst    = 1'bx;
                alu_src    = 1'b0;
                alu_op     = 2'b01;
                mem_read   = 1'b0;
                mem_write  = 1'b0;
                branch     = 1'b1;
                mem_to_reg = 1'bx;
                reg_write  = 1'b0;
            end
            OP_J, OP_JAL: begin
                jump       = 1'b1;
                reg_write  = (opcode == OP_JAL) ? 1'b1 : 1'b0; // jal writes $ra
                mem_to_reg = 1'b0;
            end
            default: begin
                // NOP / unrecognised - all signals already defaulted to 0
            end
        endcase
    end
endmodule


// ============================================================
// 3. SIGN EXTEND
// ============================================================
module sign_extend (
    input  wire [15:0] imm16,
    output wire [31:0] imm32
);
    assign imm32 = {{16{imm16[15]}}, imm16};  // replicate sign bit
endmodule


// ============================================================
// 4. REGISTER FILE
// ============================================================
module register_file (
    input  wire        clk,
    input  wire        rst,
    // Read port A
    input  wire [4:0]  rs,            // source register 1 address
    output wire [31:0] rs_data,       // source register 1 data
    // Read port B
    input  wire [4:0]  rt,            // source register 2 address
    output wire [31:0] rt_data,       // source register 2 data
    // Write port
    input  wire        reg_write,     // 1 = perform write this cycle
    input  wire [4:0]  rd,            // destination register address
    input  wire [31:0] write_data     // data to write
);
    reg [31:0] regs [0:31];

    integer i;
    // Synchronous reset and write
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'b0;
        end else if (reg_write && (rd != 5'b0)) begin
            // $zero is protected - writes to register 0 are silently dropped
            regs[rd] <= write_data;
        end
    end

    // Asynchronous read with write-through bypass
    // If WB is writing to the same register we're reading, forward new value
    assign rs_data = (reg_write && (rd == rs) && (rs != 5'b0))
                     ? write_data : regs[rs];
    assign rt_data = (reg_write && (rd == rt) && (rt != 5'b0))
                     ? write_data : regs[rt];
endmodule


// ============================================================
// 5. ID/EX PIPELINE REGISTER
// ============================================================
module id_ex_reg (
    input  wire        clk,
    input  wire        rst,
    input  wire        predictor_flush, // From Predictor
    
    // Data inputs from ID stage
    input  wire [31:0] id_pc_plus4,
    input  wire [31:0] id_rs_data,
    input  wire [31:0] id_rt_data,
    input  wire [31:0] id_imm32,
    input  wire [4:0]  id_rs,         // needed by forwarding unit
    input  wire [4:0]  id_rt,         // needed by forwarding unit & reg_dst mux
    input  wire [4:0]  id_rd,         // needed by reg_dst mux (R-type dest)
    input  wire [5:0]  id_funct,      // ALU control
    input  wire [4:0]  id_shamt,      // shift amount

    // Control inputs (bundled for cleanliness)
    input  wire        id_reg_dst,
    input  wire        id_alu_src,
    input  wire [1:0]  id_alu_op,
    input  wire        id_mem_read,
    input  wire        id_mem_write,
    input  wire        id_branch,
    input  wire        id_mem_to_reg,
    input  wire        id_reg_write,

    // Data outputs to EX stage
    output reg  [31:0] ex_pc_plus4,
    output reg  [31:0] ex_rs_data,
    output reg  [31:0] ex_rt_data,
    output reg  [31:0] ex_imm32,
    output reg  [4:0]  ex_rs,
    output reg  [4:0]  ex_rt,
    output reg  [4:0]  ex_rd,
    output reg  [5:0]  ex_funct,
    output reg  [4:0]  ex_shamt,

    // Control outputs to EX stage
    output reg         ex_reg_dst,
    output reg         ex_alu_src,
    output reg  [1:0]  ex_alu_op,
    output reg         ex_mem_read,
    output reg         ex_mem_write,
    output reg         ex_branch,
    output reg         ex_mem_to_reg,
    output reg         ex_reg_write
);
    always @(posedge clk) begin
        if (rst || predictor_flush) begin
            // Zero everything - a bubble propagates harmlessly
            ex_pc_plus4   <= 32'b0;
            ex_rs_data    <= 32'b0;
            ex_rt_data    <= 32'b0;
            ex_imm32      <= 32'b0;
            ex_rs         <= 5'b0;
            ex_rt         <= 5'b0;
            ex_rd         <= 5'b0;
            ex_funct      <= 6'b0;
            ex_shamt      <= 5'b0;
            // All control signals off
            ex_reg_dst    <= 1'b0;
            ex_alu_src    <= 1'b0;
            ex_alu_op     <= 2'b0;
            ex_mem_read   <= 1'b0;
            ex_mem_write  <= 1'b0;
            ex_branch     <= 1'b0;
            ex_mem_to_reg <= 1'b0;
            ex_reg_write  <= 1'b0;
        end else begin
            ex_pc_plus4   <= id_pc_plus4;
            ex_rs_data    <= id_rs_data;
            ex_rt_data    <= id_rt_data;
            ex_imm32      <= id_imm32;
            ex_rs         <= id_rs;
            ex_rt         <= id_rt;
            ex_rd         <= id_rd;
            ex_funct      <= id_funct;
            ex_shamt      <= id_shamt;
            ex_reg_dst    <= id_reg_dst;
            ex_alu_src    <= id_alu_src;
            ex_alu_op     <= id_alu_op;
            ex_mem_read   <= id_mem_read;
            ex_mem_write  <= id_mem_write;
            ex_branch     <= id_branch;
            ex_mem_to_reg <= id_mem_to_reg;
            ex_reg_write  <= id_reg_write;
        end
    end
endmodule


// ============================================================
// 6. HAZARD DETECTION UNIT
// ============================================================
module hazard_detection_unit (
    // From ID/EX register (the instruction currently in EX)
    input  wire        ex_mem_read,  // 1 = EX-stage instruction is a LW
    input  wire [4:0]  ex_rt,        // destination of that LW

    // From IF/ID register (the instruction currently in ID)
    input  wire [4:0]  id_rs,        // source register 1 of ID instruction
    input  wire [4:0]  id_rt,        // source register 2 of ID instruction

    // Outputs
    output wire        stall_pipeline, // 1 = stall PC and IF/ID latch
    output wire        insert_bubble   // 1 = flush ID/EX (insert NOP into EX)
);
    wire load_use_hazard;
    assign load_use_hazard = ex_mem_read &&
                             ((ex_rt == id_rs) || (ex_rt == id_rt)) &&
                             (ex_rt != 5'b0);  // $zero never causes a hazard

    assign stall_pipeline = load_use_hazard;
    assign insert_bubble  = load_use_hazard;
endmodule


// ============================================================
// 7. FORWARDING UNIT
// ============================================================
module forwarding_unit (
    // From EX stage (what registers does the current EX instruction need?)
    input  wire [4:0] ex_rs,           // source register A address
    input  wire [4:0] ex_rt,           // source register B address

    // From EX/MEM pipeline register
    input  wire        exmem_reg_write, // 1 = instruction in MEM will write a reg
    input  wire [4:0]  exmem_rd,        // destination register of that instruction

    // From MEM/WB pipeline register
    input  wire        memwb_reg_write, // 1 = instruction in WB will write a reg
    input  wire [4:0]  memwb_rd,        // destination register of that instruction

    // MUX select outputs
    output reg  [1:0] forward_a,        // MUX select for ALU input A
    output reg  [1:0] forward_b         // MUX select for ALU input B
);
    always @(*) begin
        // -- Forward A (rs) -------------------------------------
        forward_a = 2'b00;  // default: no forwarding

        // EX/MEM forwarding takes priority (more recent result)
        if (exmem_reg_write && (exmem_rd != 5'b0) && (exmem_rd == ex_rs))
            forward_a = 2'b10;
        // MEM/WB forwarding (fallback)
        else if (memwb_reg_write && (memwb_rd != 5'b0) && (memwb_rd == ex_rs))
            forward_a = 2'b01;

        // -- Forward B (rt) -------------------------------------
        forward_b = 2'b00;  // default: no forwarding

        if (exmem_reg_write && (exmem_rd != 5'b0) && (exmem_rd == ex_rt))
            forward_b = 2'b10;
        else if (memwb_reg_write && (memwb_rd != 5'b0) && (memwb_rd == ex_rt))
            forward_b = 2'b01;
    end
endmodule


// ============================================================
// 8. TOP-LEVEL DATAPATH INTEGRATION
// ============================================================
module datapath (
    input  wire        clk,
    input  wire        rst,
    input  wire        predictor_flush,
    // From teammate's icache / pc
    input  wire        icache_stall,      // cache miss stall
    input  wire [31:0] instr_from_cache,  // fetched instruction
    input  wire [31:0] pc_out,            // current PC (from pc module)

    // From EX/MEM pipeline register (teammate's EX stage or stub)
    input  wire        exmem_reg_write,
    input  wire [4:0]  exmem_rd,
    input  wire [31:0] exmem_alu_result,  // forwarded ALU result

    // From MEM/WB pipeline register (teammate's WB stage or stub)
    input  wire        memwb_reg_write,
    input  wire [4:0]  memwb_rd,
    input  wire [31:0] memwb_write_data,  // forwarded write-back data

    // Branch resolution outputs (replace stubs in teammate's top.v)
    output wire        branch_taken,
    output wire [31:0] branch_addr,

    // Pipeline stall output (OR with icache_stall for PC enable)
    output wire        pipeline_stall,
    
    // --> THE TWO NEW WIRES WE ADDED <--
    output wire        id_is_branch_o,
    output wire [31:0] id_pc_o,
    
    // ID/EX outputs - connect to your EX-stage module(s)
    output wire [31:0] ex_pc_plus4,
    output wire [31:0] ex_rs_data_o,
    output wire [31:0] ex_rt_data_o,
    output wire [31:0] ex_imm32_o,
    output wire [4:0]  ex_rs_o,
    output wire [4:0]  ex_rt_o,
    output wire [4:0]  ex_rd_o,
    output wire [5:0]  ex_funct_o,
    output wire [4:0]  ex_shamt_o,
    output wire        ex_reg_dst_o,
    output wire        ex_alu_src_o,
    output wire [1:0]  ex_alu_op_o,
    output wire        ex_mem_read_o,
    output wire        ex_mem_write_o,
    output wire        ex_branch_o,
    output wire        ex_mem_to_reg_o,
    output wire        ex_reg_write_o,

    // Forwarding mux selects - consume in EX stage
    output wire [1:0]  forward_a,
    output wire [1:0]  forward_b
);

    // -- PC+4 computed from current PC --------------------------
    wire [31:0] pc_plus4 = pc_out + 32'd4;

    // -- IF/ID register wires -----------------------------------
    wire [31:0] id_pc_plus4, id_instr;

    // -- Stall/flush logic --------------------------------------
    wire haz_stall, haz_bubble;
    wire combined_stall = icache_stall | haz_stall;
    assign pipeline_stall = combined_stall;

    // Branch logic (resolved in ID stage - early branch resolution)
    // BEQ: branch_taken when rs_data == rt_data (zero difference)
    wire [31:0] id_rs_data_raw, id_rt_data_raw;
  
    // Flush IF/ID when branch is taken
    wire if_id_flush = predictor_flush;
    wire id_ex_flush = haz_bubble;
    
    wire [31:0] id_rs_fwd = (exmem_reg_write && (exmem_rd != 5'b0) && (exmem_rd == id_rs)) ? exmem_alu_result :
                            (memwb_reg_write && (memwb_rd != 5'b0) && (memwb_rd == id_rs)) ? memwb_write_data :
                            id_rs_data_raw;

 wire [31:0] id_rt_fwd = (exmem_reg_write && (exmem_rd != 5'b0) && (exmem_rd == id_rt)) ? exmem_alu_result :
                            (memwb_reg_write && (memwb_rd != 5'b0) && (memwb_rd == id_rt)) ? memwb_write_data :
                            id_rt_data_raw;

    // ---> PASTE THIS MISSING BLOCK BACK IN <---
    wire [31:0] imm32_id;
    sign_extend u_sext_id (
        .imm16 (id_instr[15:0]),
        .imm32 (imm32_id)
    );
    wire [31:0] branch_target = id_pc_plus4 + (imm32_id << 2);
    wire [31:0] jump_target   = {id_pc_plus4[31:28], id_instr[25:0], 2'b00};
    // -----------------------------------------

    wire beq_taken = (id_opcode == 6'h04) && (id_rs_fwd == id_rt_fwd);
    wire bne_taken = (id_opcode == 6'h05) && (id_rs_fwd != id_rt_fwd);
    wire j_taken   = (id_opcode == 6'h02) || (id_opcode == 6'h03);

    assign branch_taken = beq_taken | bne_taken | j_taken;
    assign branch_addr  = j_taken ? jump_target : branch_target;
    // Fixed: Report jumps to the predictor so it can train on them 

    
    // -- IF/ID register -----------------------------------------
    if_id_reg u_if_id (
        .clk        (clk),
        .rst        (rst),
        .stall      (combined_stall),
        .predictor_flush      (if_id_flush),
        .if_pc_plus4(pc_plus4),
        .if_instr   (instr_from_cache),
        .id_pc_plus4(id_pc_plus4),
        .id_instr   (id_instr)
    );

    // -- Instruction field extraction ---------------------------
    wire [5:0]  id_opcode = id_instr[31:26];
    wire [4:0]  id_rs     = id_instr[25:21];
    wire [4:0]  id_rt     = id_instr[20:16];
    wire [4:0]  id_rd     = id_instr[15:11];
    wire [4:0]  id_shamt  = id_instr[10:6];
    wire [5:0]  id_funct  = id_instr[5:0];

    // -- Control unit -------------------------------------------
    wire id_reg_dst, id_alu_src, id_mem_read, id_mem_write;
    wire id_branch,  id_jump,    id_mem_to_reg, id_reg_write;
    wire [1:0] id_alu_op;

    control_unit u_ctrl (
        .opcode     (id_opcode),
        .reg_dst    (id_reg_dst),
        .alu_src    (id_alu_src),
        .alu_op     (id_alu_op),
        .mem_read   (id_mem_read),
        .mem_write  (id_mem_write),
        .branch     (id_branch),
        .jump       (id_jump),
        .mem_to_reg (id_mem_to_reg),
        .reg_write  (id_reg_write)
    );

    // -- Register file ------------------------------------------
    // Write-back port driven by MEM/WB signals from teammate's WB stage
    register_file u_regfile (
        .clk        (clk),
        .rst        (rst),
        .rs         (id_rs),
        .rs_data    (id_rs_data_raw),
        .rt         (id_rt),
        .rt_data    (id_rt_data_raw),
        .reg_write  (memwb_reg_write),
        .rd         (memwb_rd),
        .write_data (memwb_write_data)
    );

    // -- Hazard detection ---------------------------------------
    // Needs to see EX stage's mem_read and rt (from ID/EX output)
    wire ex_mem_read_fb, ex_rt_fb_valid;
    // We read these from the ID/EX register outputs after the fact;
    // connect ex_mem_read_o and ex_rt_o back in
    hazard_detection_unit u_hdu (
        .ex_mem_read   (ex_mem_read_o),
        .ex_rt         (ex_rt_o),
        .id_rs         (id_rs),
        .id_rt         (id_rt),
        .stall_pipeline(haz_stall),
        .insert_bubble (haz_bubble)
    );

    // -- ID/EX register -----------------------------------------
    id_ex_reg u_id_ex (
        .clk          (clk),
        .rst          (rst),
        .predictor_flush        (id_ex_flush),
        .id_pc_plus4  (id_pc_plus4),
        .id_rs_data   (id_rs_data_raw),
        .id_rt_data   (id_rt_data_raw),
        .id_imm32     (imm32_id),
        .id_rs        (id_rs),
        .id_rt        (id_rt),
        .id_rd        (id_rd),
        .id_funct     (id_funct),
        .id_shamt     (id_shamt),
        .id_reg_dst   (id_reg_dst),
        .id_alu_src   (id_alu_src),
        .id_alu_op    (id_alu_op),
        .id_mem_read  (id_mem_read),
        .id_mem_write (id_mem_write),
        .id_branch    (id_branch),
        .id_mem_to_reg(id_mem_to_reg),
        .id_reg_write (id_reg_write),
        .ex_pc_plus4  (ex_pc_plus4),
        .ex_rs_data   (ex_rs_data_o),
        .ex_rt_data   (ex_rt_data_o),
        .ex_imm32     (ex_imm32_o),
        .ex_rs        (ex_rs_o),
        .ex_rt        (ex_rt_o),
        .ex_rd        (ex_rd_o),
        .ex_funct     (ex_funct_o),
        .ex_shamt     (ex_shamt_o),
        .ex_reg_dst   (ex_reg_dst_o),
        .ex_alu_src   (ex_alu_src_o),
        .ex_alu_op    (ex_alu_op_o),
        .ex_mem_read  (ex_mem_read_o),
        .ex_mem_write (ex_mem_write_o),
        .ex_branch    (ex_branch_o),
        .ex_mem_to_reg(ex_mem_to_reg_o),
        .ex_reg_write (ex_reg_write_o)
    );

    // -- Forwarding unit ----------------------------------------
    forwarding_unit u_fwd (
        .ex_rs          (ex_rs_o),
        .ex_rt          (ex_rt_o),
        .exmem_reg_write(exmem_reg_write),
        .exmem_rd       (exmem_rd),
        .memwb_reg_write(memwb_reg_write),
        .memwb_rd       (memwb_rd),
        .forward_a      (forward_a),
        .forward_b      (forward_b)
    );
    
    // --> EXPOSE ID-STAGE SIGNALS TO TOP LEVEL <--
    assign id_is_branch_o = id_branch | id_jump;
    assign id_pc_o        = id_pc_plus4 - 32'd4;
    
endmodule


// ============================================================
// 9. TESTBENCH
// ============================================================
`timescale 1ns/1ps
module tb_datapath;

    // Clock and reset
    reg clk, rst;
    always #5 clk = ~clk;  // 100 MHz clock

    // Instruction ROM (mimics teammate's instr_from_cache)
    reg [31:0] imem [0:15];
    initial begin
        // MIPS machine code
        imem[0]  = 32'h20080005; // addi $t0, $zero, 5
        imem[1]  = 32'h20090003; // addi $t1, $zero, 3
        imem[2]  = 32'h8C0A0000; // lw   $t2, 0($zero)   - load-use hazard
        imem[3]  = 32'h01095820; // add  $t3, $t0, $t1   - forwarding test
        imem[4]  = 32'h11090002; // beq  $t0, $t1, +2    - not taken
        imem[5]  = 32'h20000000; // addi $zero,$zero,0   - NOP
        imem[6]  = 32'h00000000; // NOP
        imem[7]  = 32'h00000000; // NOP
    end

    // Simple PC for testbench (word-addressed)
    reg [31:0] pc;
    wire [31:0] instr_from_cache = imem[pc[5:2]];
    wire [31:0] pc_out_tb = pc;

    // Stub signals for EX/MEM and MEM/WB stages
    reg        exmem_reg_write, memwb_reg_write;
    reg [4:0]  exmem_rd, memwb_rd;
    reg [31:0] exmem_alu_result, memwb_write_data;

    // DUT outputs
    wire        branch_taken, pipeline_stall;
    wire [31:0] branch_addr;
    wire [31:0] ex_pc_plus4, ex_rs_data_o, ex_rt_data_o, ex_imm32_o;
    wire [4:0]  ex_rs_o, ex_rt_o, ex_rd_o, ex_shamt_o;
    wire [5:0]  ex_funct_o;
    wire        ex_reg_dst_o, ex_alu_src_o, ex_mem_read_o;
    wire        ex_mem_write_o, ex_branch_o, ex_mem_to_reg_o, ex_reg_write_o;
    wire [1:0]  ex_alu_op_o, forward_a, forward_b;
    
    // --> NEW TB WIRES ADDED HERE TO CATCH THE NEW PORTS <--
    wire        id_is_branch_o_tb;
    wire [31:0] id_pc_o_tb;

    // DUT instantiation
    datapath u_dut (
        .clk             (clk),
        .rst             (rst),
        .predictor_flush (1'b0),          // Tie off in TB
        .icache_stall    (1'b0),          // no cache miss in TB
        .instr_from_cache(instr_from_cache),
        .pc_out          (pc_out_tb),
        .exmem_reg_write (exmem_reg_write),
        .exmem_rd        (exmem_rd),
        .exmem_alu_result(exmem_alu_result),
        .memwb_reg_write (memwb_reg_write),
        .memwb_rd        (memwb_rd),
        .memwb_write_data(memwb_write_data),
        .branch_taken    (branch_taken),
        .branch_addr     (branch_addr),
        .pipeline_stall  (pipeline_stall),
        
        // --> CONNECT NEW PORTS IN TB HERE <--
        .id_is_branch_o  (id_is_branch_o_tb),
        .id_pc_o         (id_pc_o_tb),
        
        .ex_pc_plus4     (ex_pc_plus4),
        .ex_rs_data_o    (ex_rs_data_o),
        .ex_rt_data_o    (ex_rt_data_o),
        .ex_imm32_o      (ex_imm32_o),
        .ex_rs_o         (ex_rs_o),
        .ex_rt_o         (ex_rt_o),
        .ex_rd_o         (ex_rd_o),
        .ex_funct_o      (ex_funct_o),
        .ex_shamt_o      (ex_shamt_o),
        .ex_reg_dst_o    (ex_reg_dst_o),
        .ex_alu_src_o    (ex_alu_src_o),
        .ex_alu_op_o     (ex_alu_op_o),
        .ex_mem_read_o   (ex_mem_read_o),
        .ex_mem_write_o  (ex_mem_write_o),
        .ex_branch_o     (ex_branch_o),
        .ex_mem_to_reg_o (ex_mem_to_reg_o),
        .ex_reg_write_o  (ex_reg_write_o),
        .forward_a       (forward_a),
        .forward_b       (forward_b)
    );

    // Simple TB PC advance
    always @(posedge clk) begin
        if (rst)
            pc <= 32'b0;
        else if (!pipeline_stall) begin
            if (branch_taken) pc <= branch_addr;
            else              pc <= pc + 4;
        end
    end

    // Stimulus
    initial begin
        $dumpfile("tb_datapath.vcd");
        $dumpvars(0, tb_datapath);

        clk = 0; rst = 1;
        exmem_reg_write = 0; exmem_rd = 0; exmem_alu_result = 0;
        memwb_reg_write = 0; memwb_rd = 0; memwb_write_data  = 0;

        @(posedge clk); @(posedge clk);
        rst = 0;

        // Run for 30 cycles, then check
        repeat(30) @(posedge clk);

        $display("=== TB Complete ===");
        $display("forward_a=%b  forward_b=%b", forward_a, forward_b);
        $display("pipeline_stall=%b  branch_taken=%b", pipeline_stall, branch_taken);
        $finish;
    end

    // Cycle monitor
    integer cyc;
    initial cyc = 0;
    always @(posedge clk) begin
        cyc = cyc + 1;
        $display("CYC %0d | PC=%08h | stall=%b | branch=%b | ex_reg_write=%b | fwd_a=%b fwd_b=%b",
            cyc, pc, pipeline_stall, branch_taken, ex_reg_write_o, forward_a, forward_b);
    end

endmodule