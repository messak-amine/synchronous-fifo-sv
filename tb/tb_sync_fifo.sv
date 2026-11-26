`timescale 1ns/1ps
module tb_sync_fifo;
    localparam WIDTH = 8;
    localparam DEPTH = 8;

    reg clk = 0;
    reg rst_n = 0;
    reg wr_en = 0;
    reg rd_en = 0;
    reg [WIDTH-1:0] data_in = 0;
    wire [WIDTH-1:0] data_out;
    wire full, empty, rd_valid;
    wire [$clog2(DEPTH+1)-1:0] count;

    sync_fifo #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dut (
        .clk(clk), .rst_n(rst_n), .wr_en(wr_en), .rd_en(rd_en),
        .data_in(data_in), .data_out(data_out), .full(full),
        .empty(empty), .count(count), .rd_valid(rd_valid)
    );

    // The model shifts entries after a read. It has no circular pointers.
    reg [WIDTH-1:0] model [0:DEPTH-1];
    integer size = 0;
    reg [WIDTH-1:0] expected_data = 0;
    reg expected_valid;
    reg write_ok;
    integer cycle = 0;
    bit saw_occupied_reset = 0;
    bit saw_rejected_write = 0, saw_rejected_read = 0;
    bit saw_both_empty = 0, saw_both_partial = 0, saw_both_full = 0;
    integer reads_since_reset = 0, writes_since_reset = 0;
    integer slot;

    always #5 clk = ~clk;

    task automatic step(
        input bit reset_released,
        input bit write_request,
        input bit read_request,
        input logic [WIDTH-1:0] value
    );
        @(negedge clk);
        rst_n = reset_released;
        wr_en = write_request;
        rd_en = read_request;
        data_in = value;
        @(posedge clk);
        #2; // Let the monitor finish checking this edge before returning.
    endtask

    always @(posedge clk) begin
        cycle = cycle + 1;
        expected_valid = rst_n && rd_en && size > 0;
        write_ok = rst_n && wr_en && size < DEPTH;
        if (!rst_n) begin
            if (size > 0) saw_occupied_reset = 1;
            size = 0;
            expected_data = 0;
            reads_since_reset = 0;
            writes_since_reset = 0;
        end else begin
            if (wr_en && !rd_en && !write_ok) saw_rejected_write = 1;
            if (rd_en && !wr_en && !expected_valid) saw_rejected_read = 1;
            if (wr_en && rd_en) begin
                case (size)
                    0:       saw_both_empty = 1;
                    DEPTH:   saw_both_full = 1;
                    default: saw_both_partial = 1;
                endcase
            end
            if (expected_valid) begin
                expected_data = model[0];
                for (slot = 0; slot < size - 1; slot = slot + 1)
                    model[slot] = model[slot+1];
                size = size - 1;
                reads_since_reset = reads_since_reset + 1;
            end
            if (write_ok) begin
                model[size] = data_in;
                size = size + 1;
                writes_since_reset = writes_since_reset + 1;
            end
        end

        #1; // Sample outputs after the DUT's nonblocking updates.
        assert (count <= DEPTH && !(full && empty))
            else $fatal(1, "Cycle %0d: invalid FIFO state", cycle);
        assert (count === size && full === (size == DEPTH) && empty === (size == 0))
            else $fatal(1, "Cycle %0d: expected count %0d, got count=%0d full=%b empty=%b",
                        cycle, size, count, full, empty);
        assert (rd_valid === expected_valid)
            else $fatal(1, "Cycle %0d: rd_valid expected %b got %b", cycle, expected_valid, rd_valid);
        assert (data_out === expected_data)
            else $fatal(1, "Cycle %0d: data_out expected %h got %h", cycle, expected_data, data_out);
    end

    integer i;
    localparam RANDOM_CYCLES = 256;

    initial begin
        int seed;
        int unsigned random_word;

        $dumpfile("build/sync_fifo.vcd");
        $dumpvars(0, tb_sync_fifo);

        step(0, 0, 0, 0);
        step(1, 1, 0, 'hA5);
        step(1, 0, 1, 0);
        step(1, 0, 1, 0);        // Empty read
        step(1, 1, 1, 'hB6);     // Empty: write only
        step(1, 1, 1, 'hC7);     // Interior: read the old head and append

        for (i = 1; i < DEPTH; i = i + 1)
            step(1, 1, 0, i[WIDTH-1:0]);
        assert (full) else $fatal(1, "Directed fill did not reach full");
        step(1, 1, 0, 'hEE);     // Full write
        step(1, 1, 1, 'hFF);     // Full: read only
        step(1, 1, 0, 'hD8);     // Reuse storage after pointer wrap
        repeat (DEPTH) step(1, 0, 1, 0);
        assert (empty) else $fatal(1, "Directed drain did not reach empty");
        assert (reads_since_reset > DEPTH && writes_since_reset > DEPTH)
            else $fatal(1, "Directed tests missed a read or write after pointer wrap");

        step(1, 1, 0, 'h5A);
        step(0, 1, 1, 'h99);     // Reset takes priority over requests
        step(1, 0, 1, 0);

        assert (saw_occupied_reset)
            else $fatal(1, "Directed tests missed reset with stored data");
        assert (saw_rejected_write && saw_rejected_read)
            else $fatal(1, "Directed tests missed a write to full or a read from empty");
        assert (saw_both_empty && saw_both_partial && saw_both_full)
            else $fatal(1, "Directed tests must issue both requests when empty, partially full, and full");

        seed = 32'h31415926;
        random_word = $urandom(seed); // Seed the random stream once.
        repeat (RANDOM_CYCLES) begin
            random_word = $urandom;
            step(1, random_word[WIDTH], random_word[WIDTH+1], random_word[WIDTH-1:0]);
        end
        repeat (DEPTH) step(1, 0, 1, 0);

        $display("PASS: %0d checked clock edges (%0d randomized)", cycle, RANDOM_CYCLES);
        $finish;
    end
endmodule
