module tb_direct_mapped_cache #( parameter ADDR_WIDTH=16,
parameter DATA_WIDTH=8,
parameter CACHE_SIZE=16,
parameter CACHE_WORD_WIDTH=32,
parameter NUM_SETS=4) ();

    reg clk;
    reg flush;
    reg [ADDR_WIDTH-1:0] cpu_addr;
    reg cpu_addr_en;
    reg [DATA_WIDTH-1:0] cpu_data_;
    reg cpu_data_vld;
    wire [DATA_WIDTH-1:0] cpu_data;
    wire cpu_data_vld_out;
    reg is_read;
    wire hit_status;
    wire cache_busy;
    wire [ADDR_WIDTH-1:0] addr_main;
    wire addr_main_en;
    wire [CACHE_WORD_WIDTH-1:0] data_main;
    wire data_main_vld;

    assign cpu_data = cpu_data_vld?cpu_data_:'bz;

    cache DUT(.clk(clk), .addr(cpu_addr), .addr_en(cpu_addr_en), .is_rd(is_read), .flush(flush), .data(cpu_data), .data_vld(cpu_data_vld), .data_vld_out(cpu_data_vld_out), .is_hit(is_hit), .cache_busy(cache_busy), .addr_main(addr_main), .addr_main_en(addr_main_en), .data_main(data_main), .data_main_vld(data_main_vld) );

    main_mem dram(.clk(clk), .addr(addr_main), .addr_en(addr_main_en), .data(data_main), .data_vld(data_main_vld) );
    
    
    /* System-Verilog properties for functionality and coverage */

    property latency_bound;
        @(posedge clk) (cpu_addr_en && !cache_busy) |-> ##[1:5] !cache_busy;
    endproperty

    assert property(latency_bound);

    property cache_hit;
        @(posedge clk) (cpu_addr_en && !cache_busy) |-> ##2 is_hit;
    endproperty

    reg [31:0] cache_hit_count;
    
    cover property(cache_hit) cache_hit_count = cache_hit_count + 1;
    
    
    /* Testbench driver code */

    always #10 clk = ~clk;
    
    initial begin
        clk = 1'b1;
        cache_hit_count = 'b0;
        reset;
        check_random;
        $display("Cache Hit %d times out of 100000 reads", cache_hit_count);
        #500 $finish;
    end
        
    /* System Verilog Tasks used to create tests */
    //****************************************************
    task reset;
        begin
            flush = 1'b1;
            #40;
            flush = 1'b0;
            #40;
        end
    endtask

    task write; /* Returns on negative clock cycle */
        input [ADDR_WIDTH-1:0] address;
        input [DATA_WIDTH-1:0] dataval;
        begin
            #10; //Negative edge of clock
            cpu_addr = address;
            cpu_addr_en = 1'b1;
            cpu_data_ = dataval;
            cpu_data_vld = 1'b1;
            is_read = 1'b0;
            #20;
            cpu_addr = 'b0;
            cpu_addr_en = 1'b0;
            cpu_data_vld = 1'b0;
            #20;
            if(cache_busy) begin
                #20;
                if(cache_busy) begin
                    #20;
                    if(cache_busy) begin
                        #20;
                    end
                end
            end
        end
    endtask

    task read; /* Returns on negative clock cycle */
        input [ADDR_WIDTH-1:0] address;
        output [DATA_WIDTH-1:0] data;
        begin
            #10;
            cpu_addr = address;
            cpu_addr_en = 1'b1;
            is_read = 1'b1;
            cpu_data_vld = 1'b0;
            #20;
            cpu_addr = 'bx;
            cpu_addr_en = 1'b0;
            #20;
            if(cache_busy) begin
                #20;
                if(cache_busy) begin
                    #20;
                end
            end
            if(cpu_data_vld_out) 
                data = cpu_data;
            else
                $error("Read on address %h Failed!", address);
        end
    endtask
    
    task read_after_write;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        reg [DATA_WIDTH-1:0] read_data;
        write(addr, data);
        #10; //because each task assumes that it starts on posedge
        read(addr, read_data);
        if( read_data != data ) 
            $error("Read after write failed on address %h with data %h", addr, data);
        else
            $display("Completed Read after Write on address %h with data %h", addr, data);
    endtask

    task read_after_write_random;
        reg [ADDR_WIDTH-1:0] addr;
        reg [DATA_WIDTH-1:0] data;
        reg [DATA_WIDTH-1:0] read_data;
        addr = $urandom % 2**ADDR_WIDTH;
        data = $urandom % 2**DATA_WIDTH;
        write(addr, data);
        #10;
        read(addr, read_data);
        if( read_data != data ) 
            $error("Randomized read after write failed on address %h with data %h", addr, data);
        else
            $display("Completed Read after Write on address %h with data %h", addr, data);
    endtask
    
    task check_reads; //checks if reads corrupt data
        reg [ADDR_WIDTH-1:0] addr;
        reg [DATA_WIDTH-1:0] data;
        reg [DATA_WIDTH-1:0] first_read;
        reg [DATA_WIDTH-1:0] second_read;

        integer i;
        //data = 8'hff;
        for( i=0; i<2**ADDR_WIDTH; i = i+1 ) begin
            addr = i;
            data = i;
            write(addr, data);
            #10;
            read(addr, first_read);
            #10;
            read(addr, second_read);
            if(first_read != data)
                $error("Read failed at address %h", addr);
            if(second_read != data)
                $error("Read failed at address %h", addr);
        end

        $display("All Read checks are passing");
                
    endtask
    
    task check_evictions; //checks if evictions corrupt data
        reg [ADDR_WIDTH-1:0] addr;
        reg [DATA_WIDTH-1:0] data;
        reg [DATA_WIDTH-1:0] read_data;

        integer i;
        //data = 8'hff;
        for( i=0; i<2**ADDR_WIDTH; i = i+1 ) begin
            addr = i;
            data = i;
            write(addr, data);
            #10;
        end
    
        for(i=0; i<2**ADDR_WIDTH; i = i+1 ) begin
            addr = i;
            data = i;
            read(addr, read_data);
            if(data != read_data)
                $error("Eviction check failing at addr %h", addr);
        end

        $display("All Eviction checks are passing");
    endtask
    
    task check_random; //checks if random reads and writes corrupt data
        reg [ADDR_WIDTH-1:0] addr;
        reg [DATA_WIDTH-1:0] data;
        reg [DATA_WIDTH-1:0] read_data;
        parameter LIMIT= 100000;
        reg [LIMIT-1:0] [ADDR_WIDTH-1:0] mem;
        integer i;
        //data = 8'hff;
        for( i=0; i<LIMIT; i = i+1 ) begin
            addr = $urandom%(2**ADDR_WIDTH);
            data = addr;
            mem[i] = addr;
            write(addr, data);
            #10;
        end
    
        for(i=0; i<LIMIT; i = i+1 ) begin
            addr = mem[i];
            data = addr;
            read(addr, read_data);
            //$display("Data is %h", data);
            if(data != read_data)
                $error("Eviction check failing at addr %h", addr);
        end

        $display("All Random checks are passing");
    endtask

endmodule
