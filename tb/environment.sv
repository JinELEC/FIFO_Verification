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