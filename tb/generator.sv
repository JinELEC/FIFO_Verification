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
        repeat(50) begin
            assert(tr.randomize()) else $display("Randomization Failed");
            tr.display("GEN");
            mbx.put(tr.copy());
            @(sconext);
        end
        -> done;
    endtask

endclass