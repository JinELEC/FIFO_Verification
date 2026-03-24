// --------------------- Interface ---------------------
interface fifo_if(input logic clk);
    logic       rst; // active high
    logic       wr_en;
    logic       rd_en;
    logic [7:0] din;
    logic [7:0] dout;
    logic       full;
    logic       empty;

    // clocking block
    clocking cb @(posedge clk);
        default input #1ns output #1ns;

        // signals for driver
        output       rst; 
        output       wr_en;
        output       rd_en;
        output       din;

        // signals for monitor
        input        dout;
        input        full;
        input        empty;
    endclocking
    
    // Assertion
    property p1;
        @(posedge clk) disable iff(rst)
        $rose(wr_en) |-> !full;
    endproperty: p1

    AP1: assert property (p1);


    property p2;
        @(posedge clk) disable iff(rst)
        $rose (rd_en) |-> !empty;
    endproperty: p2

    AP2: assert property (p2);


endinterface