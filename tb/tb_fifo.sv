// ======================= Interface ======================= //
interface fifo_if #(parameter WIDTH = 4) (input logic clk);
    logic             n_rst; // active low                 
    logic             we; 
    logic             re;  
    logic [WIDTH-1:0] wrdata;  
    logic [WIDTH-1:0] rddata;  
    logic             full; 
    logic             almost_full; 
    logic             empty; 
    logic             almost_empty;

    // driver clocking block
    clocking drv_cb @(posedge clk);
        default input #1ns output #1ns;
        output n_rst;
        output we;
        output re;
        output wrdata;
    endclocking

    // monitor clocking block
    clocking mon_cb @(posedge clk);
        default input #1ns output #1ns;
        input we;
        input re;
        input wrdata;
        input rddata;
        input full;
        input almost_full;
        input empty;
        input almost_empty;
    endclocking

    // Assertion 추가
    // when we = 1, FIFO is not full
    property p1;
        @(posedge clk) disable iff (!n_rst)
        we |-> !full;
        // we |-> full
    endproperty: p1

    AS1: assert property (p1);

    // check full & empty at the same time
    property p2;
        @(posedge clk) disable iff (!n_rst)
            !(full && empty);
    endproperty: p2

    AS2: assert property (p2);

    // check almost_full & almost_full at the same time
    property p3;
        @(posedge clk) disable iff (!n_rst)
            !(almost_full & almost_empty);
    endproperty: p3

    AS3: assert property (p3);


endinterface

// ======================= Transaction ======================= //
class transaction #(parameter WIDTH = 4);
    rand bit             we;
    rand bit             re;
    rand bit [WIDTH-1:0] wrdata;
         bit [WIDTH-1:0] rddata;
    bit                  full;
    bit                  almost_full;
    bit                  empty;
    bit                  almost_empty;

    constraint control_wr_re { // except both we and re are zero
        !(we == 0 && re == 0);
        we dist {0:=50, 1:=50};
        re dist {0:=50, 1:=50};
    } 

    // display function
    function void display(input string component);
        $display("[%s]: WE: %d, RE: %d, WRDATA: %d, RDDATA: %d", component, we, re, wrdata, rddata);
    endfunction

    function transaction copy();
        copy = new();
        copy.we           = this.we;
        copy.re           = this.re;
        copy.wrdata       = this.wrdata;
        copy.rddata       = this.rddata;
        copy.full         = this.full;
        copy.almost_full  = this.almost_full;
        copy.empty        = this.empty;
        copy.almost_empty = this.almost_empty;
    endfunction

endclass

// ======================= Generator ======================= //
class generator #(parameter WIDTH = 4);
    transaction tr;
    mailbox #(transaction) mbx;
    event done;
    event sconext;

    // constructor
    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
        tr = new();
    endfunction

    // main task
    task run();
        repeat(500) begin
            assert(tr.randomize()) else $display("Randomization Failed");
            mbx.put(tr.copy());
            tr.display("GEN");
            @(sconext); // wait until scoreboard's work done
        end
        -> done; // send all transactions
    endtask

endclass

// ======================= Driver ======================= //
class driver #(parameter WIDTH = 4);
    virtual fifo_if fif;
    transaction tr;
    mailbox #(transaction) mbx;

    // constructor 
    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
    endfunction

    // reset DUT
    task reset();
        fif.drv_cb.n_rst  <= 1'b0; // trigger reset
        fif.drv_cb.we     <= 1'b0;
        fif.drv_cb.re     <= 1'b0;
        fif.drv_cb.wrdata <= '0;
        repeat(3) @(fif.drv_cb); // reset for 3-clock
        fif.drv_cb.n_rst  <= 1'b1;
    endtask

    // write 
    task write();
        fif.drv_cb.n_rst  <= 1'b1;
        fif.drv_cb.we     <= 1'b1; // trigger we
        fif.drv_cb.re     <= 1'b0;
        fif.drv_cb.wrdata <= tr.wrdata;
        @(fif.drv_cb);
        fif.drv_cb.we     <= 1'b0;
        // @(fif.cb);
    endtask

    // read
    task read();
        fif.drv_cb.n_rst <= 1'b1;
        fif.drv_cb.we    <= 1'b0;
        fif.drv_cb.re    <= 1'b1; // trigger re
        @(fif.drv_cb);
        fif.drv_cb.re    <= 1'b0;
        // @(fif.cb);
    endtask

    // write & read at the same time
    task write_read();
        fif.drv_cb.n_rst <= 1'b1;
        fif.drv_cb.we    <= 1'b1;
        fif.drv_cb.re    <= 1'b1;
        fif.drv_cb.wrdata <= tr.wrdata;
        @(fif.drv_cb);
        fif.drv_cb.we    <= 1'b0;
        fif.drv_cb.re    <= 1'b0;
        // @(fif.cb);
    endtask

    // main task
    task run();
        forever begin
            mbx.get(tr);
            if((tr.re == 1'b1) && (tr.we == 1'b1)) write_read();
            else if(tr.we == 1'b1) write();
            else if(tr.re == 1'b1) read();
        end
    endtask

endclass

// ======================= Monitor ======================= //
class monitor #(parameter WIDTH = 4);
    virtual fifo_if fif;
    transaction tr;
    mailbox #(transaction) mbx; // to sco
    mailbox #(transaction) mbx_; // to cov

    // constructor
    function new(mailbox #(transaction) mbx, mailbox #(transaction) mbx_);   
        this.mbx  = mbx;
        this.mbx_ = mbx_;
    endfunction

   task run();
    forever begin
        tr = new();
            @(fif.mon_cb); // to sample at posedge
            if(fif.mon_cb.we || fif.mon_cb.re) begin
                tr.we           = fif.mon_cb.we;
                tr.re           = fif.mon_cb.re;
                tr.full         = fif.mon_cb.full;
                tr.almost_full  = fif.mon_cb.almost_full;
                tr.empty        = fif.mon_cb.empty;
                tr.almost_empty = fif.mon_cb.almost_empty;
                tr.wrdata       = fif.mon_cb.wrdata;
                if(fif.mon_cb.re) begin
                @(fif.mon_cb);
                tr.rddata = fif.mon_cb.rddata;
                end
                /* if(fif.re || (fif.re && fif.we)) begin
                    @(fif.cb);
                    tr.rddata   = fif.rddata;
                end
                else
                    tr.rddata   = fif.rddata; */
                tr.display("MON");
                mbx.put(tr); // send to sco
                mbx_.put(tr); // send to cov
            end
    end
   endtask 

endclass

// ======================= Scoreboard ======================= //
class scoreboard #(parameter WIDTH = 4);
    transaction tr;
    mailbox #(transaction) mbx;
    event sconext;
    bit [WIDTH-1:0] wrdata[$]; // queue
    bit [WIDTH-1:0] temp;

    function new(mailbox #(transaction) mbx);   
        this.mbx = mbx;
    endfunction

    // main task
    task run();
        forever begin
            mbx.get(tr);
            if(tr.we == 1'b1) begin
                if(tr.full != 1'b1) begin
                    wrdata.push_front(tr.wrdata); // push input data into a queue
                end
                else
                    $display("[SCO]: FIFO is Full");
            end

            if(tr.re == 1'b1) begin
                if(tr.empty != 1'b1) begin
                    temp = wrdata.pop_back(); // pop input data from a queue

                    if(temp == tr.rddata) begin
                        tr.display("SCO");
                        $display("[SCO]: Data Matched");
                    end
                    else begin
                        tr.display("SCO");
                        $display("[SCO]: Data Mismatched");
                    end
                end
                else $display("[SCO]: FIFO is Empty");
            end
        -> sconext;
        end
    endtask

endclass
// 1. write 인데 full 이 아닌 경우 -> queue 에 대입
// 2. write 인데 full 인 경우 -> full 알림
// 3. read 인데 empty 가 아닌 경우 -> 
// 4. read 인데 empty 인 경우 -> empty 알림

// ======================= Coverage ======================= //
class my_coverage;
    transaction tr;
    mailbox #(transaction) mbx_; // from mon

    covergroup cg;
        option.per_instance = 1;

        cp_we : coverpoint tr.we {
            bins we_value[] = {0, 1};
        }

        cp_re : coverpoint tr.re {
            bins re_value[] = {0, 1};
        }

        cp_full : coverpoint tr.full {
            bins full_value[] = {0, 1};
        }

        cp_almost_full : coverpoint tr.almost_full {
            bins almost_full_value[] = {0, 1};
        }

        cp_empty : coverpoint tr.empty {
            bins empty_value[] = {0, 1};
        }
        
        cp_almost_empty : coverpoint tr.almost_empty {
            bins almost_empty_value[] = {0, 1};
        }

        cp_wrdata : coverpoint tr.wrdata { bins wrdata[] = {[0:15]}; }
        cp_rddata : coverpoint tr.rddata { bins rddata[] = {[0:15]}; }

        // 1. we, re 둘 다 1인 경우, we = 0 & re = 1 인 경우, we = 1 & re = 0 인 경우
        cross_we_re : cross cp_we, cp_re { 
            ignore_bins ignore_we_re_zero = binsof(cp_we) intersect {0} && binsof(cp_re) intersect {0};
        }


        cross_we_re_full : cross cp_we, cp_re, cp_full {
            ignore_bins ignore_1 = binsof(cp_we) intersect {0} && binsof(cp_re) intersect {0};
            
        }  

        cross_we_re_empty : cross cp_we, cp_re, cp_empty {
            ignore_bins ignore_2 = binsof(cp_we) intersect {0} && binsof(cp_re) intersect {0};
        }

    endgroup

    // constructor
    function new(mailbox #(transaction) mbx);
        this.mbx_ = mbx;
        cg = new();
    endfunction

    // main task
    task run();
        forever begin
            mbx_.get(tr);
            cg.sample();
        end
    endtask

endclass

    
// ======================= Environment ======================= //
class environment #(parameter WIDTH = 4);
    generator  #(WIDTH) gen;
    driver     #(WIDTH) drv;
    monitor    #(WIDTH) mon;
    scoreboard #(WIDTH) sco;
    my_coverage         cov;
    event next;

    mailbox #(transaction) gdmbx; // gen - drv
    mailbox #(transaction) msmbx; // mon - sco
    mailbox #(transaction) mcmbx; // mon - cov

    virtual fifo_if fif;

    function new(virtual fifo_if fif);
        gdmbx = new();
        msmbx = new();
        mcmbx = new();
        
        gen = new(gdmbx);
        drv = new(gdmbx);
        mon = new(msmbx, mcmbx);
        sco = new(msmbx);
        cov = new(mcmbx);

        // connect interface
        this.fif = fif;
        drv.fif = this.fif;
        mon.fif = this.fif;

        // connect event
        gen.sconext = next;
        sco.sconext = next;
    endfunction

    // pre test
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

    // post test
    task post_test();
        wait(gen.done.triggered);
        #100;
        $finish;
    endtask

    // main task
    task run();
        pre_test();
        fork
            test();
            post_test();
        join
    endtask

endclass


// ======================= Testbench Top ======================= //
module tb #(parameter WIDTH = 4);
    logic clk;
    environment env;
    fifo_if #(.WIDTH(WIDTH)) fif(clk);

    fifo #( .WIDTH(WIDTH)
    ) dut(
        .clk            (clk),
        .n_rst          (fif.n_rst),
        .we             (fif.we),
        .re             (fif.re),
        .wrdata         (fif.wrdata),
        .rddata         (fif.rddata),
        .full           (fif.full),
        .almost_full    (fif.almost_full),
        .empty          (fif.empty),
        .almost_empty   (fif.almost_empty)
    );

    initial begin
        clk <= 1'b0;
    end

    always #5 clk <= ~clk;

    initial begin
        env = new(fif);
        env.run();
    end

    // Waveform
    initial begin
    $dumpfile("wave.vcd");     
    $dumpvars(0, tb); 
    end

endmodule
