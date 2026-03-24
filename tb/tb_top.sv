// --------------------- Testbench top ---------------------
`include "fifo_if.sv"
import fifo_pkg::*;

module tb;
    logic clk;
    fifo_if fif(clk);

    fifo dut(
        .clk    (fif.clk        ),
        .rst    (fif.rst        ),
        .wr_en  (fif.wr_en      ),
        .rd_en  (fif.rd_en      ),
        .din    (fif.din        ),
        .dout   (fif.dout       ),
        .full   (fif.full       ),
        .empty  (fif.empty      )
    );

    initial begin
        clk <= 1'b0;
    end

    always #5 clk <= ~clk;

    environment env;

    initial begin
        env = new(fif);
        env.run();
    end
    
    // Stimulus
    initial begin
    $dumpfile("wave.vcd");     
    $dumpvars(0, tb); 
    end

endmodule