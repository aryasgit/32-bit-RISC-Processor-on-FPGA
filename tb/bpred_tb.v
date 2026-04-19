`timescale 1ns / 1ps

module bpred_tb;

reg         clk;
    reg         rst;
    reg  [31:0] fetch_pc;
    reg         ex_branch_valid;
    reg         ex_branch_taken;
    reg  [31:0] ex_branch_target;
    reg  [31:0] ex_pc;

    // --- Outputs from the DUT (Driven by the module, so they MUST be wires) ---
    wire        predict_taken;
    wire [31:0] target_addr;
    wire        mispredict_pulse;


  branch_predictor DUT (
  .clk(clk),
  .rst(rst),
  .fetch_pc(fetch_pc),
  .predict_taken(predict_taken),
  .target_addr(target_addr),
  .ex_branch_valid(ex_branch_valid),
  .ex_branch_taken(ex_branch_taken),
  .ex_branch_target(ex_branch_target),
  .ex_pc(ex_pc),
  .mispredict_pulse(mispredict_pulse)
  );

  initial clk = 0;
  always #5 clk = ~clk;


task check;
  input condition;
  input [255:0] name;
  begin 
    if (condition) $display (" [PASS] %s", name);
    else $display (" [FAIL] %s", name);
    end
endtask


task resolve_branch;
  input taken;
  begin 
    @(posedge clk);
    #1;
    ex_branch_valid =1'b1;
    ex_branch_taken =taken;
    ex_branch_target= 32'h00000004;
    ex_pc = 32'h00000010;

    @(posedge clk);
    #1;
    ex_branch_valid = 1'b0;
    end 

  endtask

  initial begin
        $display("================================================");
        $display("  Branch Predictor Learning Test - Shashwat S.");
        $display("================================================");

        rst =1;
        fetch_pc =32'b0;
        ex_branch_valid=0;
        ex_branch_taken=0;
        ex_branch_target=32'b0;
        ex_pc =32'h0;

        @(posedge clk); @(posedge clk);
        rst = 0;
        @(posedge clk); #1;

        $display("\n--- Setting up the Loop ---");
        $display("Branch is at PC = 0x10. Target is PC = 0x04.");
        
        // Let's set the Fetch PC to the branch instruction
        fetch_pc = 32'h00000010;
        #1; // Combinational delay

        // ========================================================
        // ITERATION 1: Initial State (Strongly Not Taken: 00)
        // ========================================================
        $display("\n--- Iteration 1 (State: 00) ---");
        check(predict_taken == 1'b0, "Predicts NOT TAKEN (Cold start)");
        
        // Execute stage tells the predictor: "Actually, we took the jump!"
        resolve_branch(1'b1);
        check(mispredict_pulse == 1'b1, "Mispredict pulse fired!");

        // ========================================================
        // ITERATION 2: State is now Weakly Not Taken (01)
        // ========================================================
        $display("\n--- Iteration 2 (State: 01) ---");
        fetch_pc = 32'h00000010; #1;
        check(predict_taken == 1'b0, "Predicts NOT TAKEN (Still learning...)");
        
        resolve_branch(1'b1);
        check(mispredict_pulse == 1'b1, "Mispredict pulse fired!");

        // ========================================================
        // ITERATION 3: State is now Weakly Taken (10)
        // ========================================================
        $display("\n--- Iteration 3 (State: 10) ---");
        fetch_pc = 32'h00000010; #1;
        check(predict_taken == 1'b1, "Predicts TAKEN! (The predictor learned!)");
        check(target_addr == 32'h00000004, "Target address is correct");
        
        resolve_branch(1'b1);
        check(mispredict_pulse == 1'b0, "NO Mispredict pulse! Perfect prediction.");

        // ========================================================
        // ITERATION 4: State is now Strongly Taken (11)
        // ========================================================
        $display("\n--- Iteration 4 (State: 11) ---");
        fetch_pc = 32'h00000010; #1;
        check(predict_taken == 1'b1, "Predicts TAKEN! (Confident)");
        
        resolve_branch(1'b1);
        check(mispredict_pulse == 1'b0, "NO Mispredict pulse! Perfect prediction.");

        // ========================================================
        // ITERATION 5: The Loop Exit
        // ========================================================
        $display("\n--- Iteration 5: Loop Exit ---");
        fetch_pc = 32'h00000010; #1;
        check(predict_taken == 1'b1, "Predicts TAKEN (Because it's usually taken)");
        
        // Loop is over, so the Execute stage says: "We didn't take it this time."
        resolve_branch(1'b0);
        check(mispredict_pulse == 1'b1, "Mispredict pulse fired on loop exit (Expected behavior).");

        $display("\n================================================");
        $display("  Simulation Complete.");
        $display("================================================");
        
        #50; $finish;
    end
endmodule
