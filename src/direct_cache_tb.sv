module direct_cache_tb #( parameter ADDR_WIDTH=16,
parameter DATA_WIDTH=8,
parameter CACHE_SIZE=16,
parameter CACHE_WORD_WIDTH=32,
parameter NUM_SETS=4) ();

    reg clk;
    reg flush;
    reg [ADDR_WIDTH-1:0] cpu_addr;
    reg cpu_addr_en;
    reg [DATA_WIDTH-1:0] cpu_data_;
    reg cpu_data_vld_;
    wire [DATA_WIDTH-1:0] cpu_data;
    wire cpu_data_vld;
    reg is_read;
    wire hit_status;
    wire cache_busy;
    wire [ADDR_WIDTH-1:0] addr_main;
    wire addr_main_en;
    wire [CACHE_WORD_WIDTH-1:0] data_main;
    wire data_main_vld;

    assign cpu_data_vld = cpu_data_vld_; 
    assign cpu_data = cpu_data_vld_?cpu_data_:'bz;

    direct_cache DUT(.clk(clk), .addr(cpu_addr), .addr_en(cpu_addr_en), .is_rd(is_read), .flush(flush), .data(cpu_data), .data_vld(cpu_data_vld), .is_hit(is_hit), .cache_busy(cache_busy), .addr_main(addr_main), .addr_main_en(addr_main_en), .data_main(data_main), .data_main_vld(data_main_vld) );

    main_mem dram(.clk(clk), .addr(addr_main), .addr_en(addr_main_en), .data(data_main), .data_vld(data_main_vld) );
    
    always begin
        #5 clk = ~clk;
    end

    initial begin
    
    $dumpfile("debug.vcd");
    $dumpvars(0, direct_cache_tb);


    clk = 1'b1;
    #10 flush = 1'b1;
    #20 flush = 1'b0;
    #20
    cpu_addr = 16'habcd;
    cpu_addr_en = 1'b1;
    is_read = 1'b0;
    cpu_data_ = 8'haa;
    cpu_data_vld_ = 1'b1;
    #20
    cpu_addr_en = 1'b0;
    cpu_data_ = 8'bxx;
    cpu_data_vld_ = 1'b0;
    #50
    cpu_addr = 16'habcd;
    $monitor("The written value is %h", cpu_data);
    cpu_addr_en = 1'b1;
    is_read = 1'b1;
    #30
    cpu_addr_en = 1'b0;
    #30
    #1000 $finish;
    end
endmodule
