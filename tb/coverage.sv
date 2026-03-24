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