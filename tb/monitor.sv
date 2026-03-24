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
                if(fif.cb.wr_en || fif.cb.rd_en) begin
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