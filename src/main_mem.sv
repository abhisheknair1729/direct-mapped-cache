module main_mem #(parameter ADDR_WIDTH=16,
                  parameter DATA_WIDTH=32) 
                  (clk, addr, addr_en, data, data_vld, flush );

    input wire clk;
    input wire flush;
    input wire [ADDR_WIDTH-1:0] addr;
    input wire addr_en;
    inout wire [DATA_WIDTH-1:0] data;
    input wire data_vld;
    
    parameter WORD_SIZE = 8;
    parameter ADDR_MASK = 16'hFFFC; //Last two bits are zeroed out

    reg [DATA_WIDTH-1:0] data_;
    reg data_vld_;
    
    parameter SIZE = 2 ** (ADDR_WIDTH - $clog2(DATA_WIDTH/WORD_SIZE));

    reg [SIZE-1:0][DATA_WIDTH-1:0] mem;

    always@(posedge clk) begin
        if(flush) begin
            mem <= 'b0;
        end
        else begin
            if(addr_en && data_vld ) begin //write
                mem[addr & ADDR_MASK] <= data;
            end
            else if(addr_en) begin //read
                data_ <= mem[addr & ADDR_MASK];
                data_vld_ <= 1'b1;
            end
        end
    end

    assign data = data_vld_?data_:'bz;

endmodule
