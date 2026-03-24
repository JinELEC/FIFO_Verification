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

        repeat(5) @(fif.cb); // keep for 5-clock

        fif.cb.rst   <= 1'b0;
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