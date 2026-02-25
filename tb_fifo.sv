// --------------------- Interface ---------------------
interface fifo_if(input logic clk);
    logic       rst; // active high
    logic       wr_en;
    logic       rd_en;
    logic [7:0] din;
    logic [7:0] dout;
    logic       full;
    logic       empty;

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
        // input        din;
        // input        wr_en;
        // input        rd_en;

    endclocking
        

endinterface

// --------------------- Transaction ---------------------
class transaction;
    rand bit [7:0] din; // input 
    rand bit       oper;
    rand bit       wr_en;
    rand bit       rd_en;
    bit      [7:0] dout;
    bit            full; 
    bit            empty;

    // display function
    function void display(input string component);
        $display("[%s]: wr_en: %b\t rd_en: %b\t din: %d", component, wr_en, rd_en, din);
    endfunction

    // constraint
    constraint control_oper{
        oper dist {0:=50, 1:=50};
        if(oper == 1'b1) {
            wr_en == 1'b1;
            rd_en == 1'b0;
        }
        else {
            wr_en == 1'b0;
            rd_en == 1'b1;
        }
    } 

    // deep copy
    function transaction copy();
        copy = new();
        copy.din   = this.din;
        copy.oper  = this.oper;
        copy.wr_en = this.wr_en;
        copy.rd_en = this.rd_en;
        copy.dout  = this.dout;
        copy.full  = this.full;
        copy.empty = this.empty;
    endfunction

endclass

// --------------------- Generator ---------------------
class generator;
    transaction tr;
    mailbox #(transaction) mbx;
    event done, sconext;

    // constructor
    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
        tr = new();
    endfunction

    // randomization
    task run();
        repeat(1000) begin
            assert(tr.randomize()) else $display("Randomization Failed");
            tr.display("GEN");
            mbx.put(tr.copy());
            @(sconext);
        end
        -> done;
    endtask

endclass

// --------------------- Driver ---------------------
class driver;
    virtual fifo_if fif;
    transaction tr;
    mailbox #(transaction) mbx;
    event drvnext;
    bit [5:0] cnt = 5'b0;

   
    // constructor
    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
    endfunction

    // reset DUT
    task reset();
        fif.cb.rst   <= 1'b1; // trigger reset
        fif.cb.wr_en <= 1'b0;
        fif.cb.rd_en <= 1'b0;
        fif.cb.din   <= 8'b0;

        repeat(5) @(fif.cb); // keep for 3-clock

        fif.cb.rst <= 1'b1;
        // @(fif.cb); // stable for after reset
    endtask

    // write 
    task write();
            // @(fif.cb);
            fif.cb.rst   <= 1'b0;
            fif.cb.wr_en <= 1'b1;
            fif.cb.rd_en <= 1'b0;
            fif.cb.din   <= tr.din;
            @(fif.cb);
            fif.cb.wr_en <= 1'b0;
            @(fif.cb);
    endtask

    // read
    task read();
            @(fif.cb);
            fif.cb.rst   <= 1'b0;
            fif.cb.wr_en <= 1'b0;
            fif.cb.rd_en <= 1'b1;
            @(fif.cb);
            fif.cb.rd_en <= 1'b0;
            @(fif.cb);
    endtask

    // main task
    task run();
        forever begin
            mbx.get(tr);
            if(tr.wr_en == 1'b1) write();
            else if(tr.rd_en == 1'b1) read();
        end
    endtask

endclass

// --------------------- Monitor ---------------------
class monitor;
    virtual fifo_if fif;
    transaction tr;
    mailbox #(transaction) mbx;
    mailbox #(transaction) mbx_;

    // constructor
    function new(mailbox #(transaction) mbx, mailbox #(transaction) mbx_);
        this.mbx = mbx;
        this.mbx_ = mbx_;
    endfunction

    // main task
    task run();
        forever begin
            tr = new();
                @(fif.cb);
                if(fif.wr_en || fif.rd_en) begin
                tr.wr_en = fif.wr_en;
                tr.rd_en = fif.rd_en;
                tr.full  = fif.full;
                tr.empty = fif.empty;
                tr.din   = fif.din;

                if(fif.rd_en) begin
                @(fif.cb);
                tr.dout = fif.dout;
                end
                else tr.dout = fif.dout;
                mbx.put(tr);
                mbx_.put(tr); // to covergroup
                end
        end
    endtask

endclass

// --------------------- Scoreboard ---------------------
class scoreboard;
    transaction tr;
    mailbox #(transaction) mbx;
    event sconext;

    // constructor
    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
    endfunction

    bit [7:0] din[$]; // queue
    bit [7:0] temp;   // temporarly store value

    task run();
        forever begin
            mbx.get(tr);
            if(tr.wr_en == 1'b1) begin
                if(tr.full != 1'b1) begin
                    din.push_back(tr.din); // input data from backward
                end
                else begin
                    $display("[SCO]: FIFO is full");
                end
            end

            if(tr.rd_en == 1'b1) begin
                if(tr.empty != 1'b1) begin
                    temp = din.pop_front(); // output data from front

                    if(tr.dout == temp) $display("[SCO]: Data Matched");
                    else $display("[SCO]: Data Mismatched");
                end
            else $display("[SCO]: FIFO is empty");
            end
        -> sconext;
        end
    endtask

endclass

// --------------------- Coverage ---------------------
class my_coverage;
    transaction tr;
    mailbox #(transaction) mbx;

    covergroup cg;
        option.per_instance = 1;

        cp_wr_en : coverpoint tr.wr_en {
            bins zero = {0};
            bins one  = {1};
        }

        cp_rd_en : coverpoint tr.rd_en {
            bins zero = {0};
            bins one  = {1};
        }

        cp_full : coverpoint tr.full {
            bins zero = {0};
            bins one  = {1};
        }

        cp_empty : coverpoint tr.empty {
            bins zero = {0};
            bins one  = {1};
        }

        cp_din   : coverpoint tr.din   { bins din = {[0:255]};  }
        cp_dout  : coverpoint tr.dout  { bins dout = {[0:255]}; }

        cross_wr_rd : cross cp_wr_en, cp_rd_en {
            // both 0
            bins both_zero = binsof(cp_wr_en.zero) && binsof(cp_rd_en.zero);

            // only write
            bins only_write = binsof(cp_wr_en.one) && binsof(cp_rd_en.zero);

            // only read
            bins only_read = binsof(cp_wr_en.zero) && binsof(cp_rd_en.one);

            // both 1 
            illegal_bins both_one = binsof(cp_wr_en.one) && binsof(cp_rd_en.one);
        }
    
    endgroup

     // constructor 
    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
        cg = new();
    endfunction

    // main task
    task run();
        forever begin
            mbx.get(tr);    
            cg.sample();
        end
    endtask  

endclass


// --------------------- Environment ---------------------
class environment;
    virtual fifo_if fif;

    generator gen;
    driver drv;
    monitor mon;
    scoreboard sco;
    my_coverage cov;

    mailbox #(transaction) gdmbx; // gen - drv
    mailbox #(transaction) msmbx; // mon - sco
    mailbox #(transaction) mcmbx; // mon - cov

    event next;

    function new(virtual fifo_if fif);
        gdmbx = new();
        msmbx = new();
        mcmbx = new();

        gen = new(gdmbx);
        drv = new(gdmbx);
        mon = new(msmbx, mcmbx);
        sco = new(msmbx);
        cov = new(mcmbx);

        gen.sconext = next;
        sco.sconext = next;

        this.fif = fif;
        drv.fif = this.fif;
        mon.fif = this.fif;
    
    endfunction

    // pre_test
    task pre_test();
        drv.reset();
    endtask

    // test
    task test();
        fork
            gen.run();
            drv.run();
            mon.run();
            sco.run();
            cov.run();
        join_any
    endtask

    // post_test
    task post_test();
        wait(gen.done.triggered);
        #1000;
        $finish;
    endtask

    // task top
    task run();
        pre_test();
        fork
            test();
            post_test();
        join
    endtask

endclass

// --------------------- Testbench top ---------------------
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
