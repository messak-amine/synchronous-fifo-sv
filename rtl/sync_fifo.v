`timescale 1ns/1ps
module sync_fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 8
) (
    input wire clk,
    input wire rst_n,
    input wire wr_en,
    input wire rd_en,
    input wire [WIDTH-1:0] data_in,
    output reg [WIDTH-1:0] data_out,
    output wire full,
    output wire empty,
    output reg [$clog2(DEPTH+1)-1:0] count,
    output reg rd_valid
);
    localparam PTR_WIDTH = $clog2(DEPTH);
    localparam COUNT_WIDTH = $clog2(DEPTH+1);
    localparam [COUNT_WIDTH-1:0] CAPACITY = DEPTH[COUNT_WIDTH-1:0];

    reg [WIDTH-1:0] memory [0:DEPTH-1];
    reg [PTR_WIDTH-1:0] read_ptr, write_ptr;
    wire accept_write = wr_en && !full;
    wire accept_read = rd_en && !empty;

    assign full = (count == CAPACITY);
    assign empty = (count == 0);

    always @(posedge clk) begin
        if (rst_n && accept_write)
            memory[write_ptr] <= data_in;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            read_ptr <= 0;
            write_ptr <= 0;
            count <= 0;
            data_out <= 0;
            rd_valid <= 0;
        end else begin
            // Pointer overflow wraps at DEPTH for power-of-two depths.
            if (accept_write)
                write_ptr <= write_ptr + 1'b1;
            if (accept_read) begin
                data_out <= memory[read_ptr];
                read_ptr <= read_ptr + 1'b1;
            end
            rd_valid <= accept_read;

            // Both requests use occupancy before the edge.
            case ({accept_write, accept_read})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: ;
            endcase
        end
    end
endmodule
