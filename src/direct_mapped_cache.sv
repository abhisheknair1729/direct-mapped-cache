module cache #(
  parameter ADDR_WIDTH=16,
  parameter DATA_WIDTH=8,
  parameter CACHE_SIZE=16,
  parameter CACHE_WORD_WIDTH=32,
  parameter NUM_SETS=4)
(clk ,addr, addr_en, is_rd, flush, data, data_vld, data_vld_out, is_hit, cache_busy,
  addr_main, addr_main_en, data_main, data_main_vld);
    
    input wire clk;
    input wire [ADDR_WIDTH-1:0] addr;
    input wire addr_en;
    input wire is_rd;
    input wire flush;
    inout wire [DATA_WIDTH-1:0] data;
    input wire data_vld;
    output wire is_hit;
    output wire cache_busy;
    output wire data_vld_out;
    
    output wire [ADDR_WIDTH-1:0] addr_main;
    output wire addr_main_en;
    
    inout wire [CACHE_WORD_WIDTH-1:0] data_main;
    output wire data_main_vld;

    //internal variables
    //*************************************************
    parameter TAG_WIDTH = ADDR_WIDTH - $clog2(CACHE_SIZE) - $clog2(CACHE_WORD_WIDTH) + $clog2(DATA_WIDTH);
    parameter OFFSET_WIDTH = $clog2(CACHE_WORD_WIDTH) - $clog2(DATA_WIDTH);
    parameter REP_POL_SIZE = 2; //LRU WITH 2 BIT HISTORY
    parameter META_DATA_WIDTH = TAG_WIDTH + 1/*DIRTY BIT*/ + 1/*PRESENT BIT*/ + REP_POL_SIZE;
    parameter DIRTY_BIT_POS = META_DATA_WIDTH - TAG_WIDTH - 1; 
    parameter PRESENT_BIT_POS = META_DATA_WIDTH - TAG_WIDTH - 2;
    parameter HISTORY_BITS_POS_START = META_DATA_WIDTH - TAG_WIDTH - 3;
    parameter HISTORY_BITS_POS_END = META_DATA_WIDTH - TAG_WIDTH - 2 - REP_POL_SIZE;
    //CACHE MEMORY
    reg [CACHE_SIZE-1:0][CACHE_WORD_WIDTH-1:0] mem;
    //cache meta data
    reg [CACHE_SIZE-1:0][META_DATA_WIDTH-1:0] meta;
    
    reg [ADDR_WIDTH-1:0] addr_;
    reg [DATA_WIDTH-1:0] data_;
    reg data_vld_;
    reg is_rd_;
    reg cache_busy_;
    reg is_hit_;
    reg [ADDR_WIDTH-1:0] addr_main_;
    reg [CACHE_WORD_WIDTH-1:0] data_main_;
    reg addr_main_en_;
    reg data_main_vld_;
    reg read_pending_;
    reg write_pending_;

    reg [TAG_WIDTH-1:0] tag;
    reg [OFFSET_WIDTH-1:0] offset;
    reg [$clog2(CACHE_SIZE)-1:0] cache_idx;
    reg is_dirty;
    reg is_present;
    reg [REP_POL_SIZE-1:0] history;
    reg write_extra_cycle_;
    
    always@(posedge clk) begin
        if(addr_en && !cache_busy_) begin
            addr_  <= addr;
            is_rd_ <= is_rd;
            tag    <= addr[ADDR_WIDTH-1 -: TAG_WIDTH];
            offset <= addr[0 +: OFFSET_WIDTH];
            cache_idx  <= addr[OFFSET_WIDTH +: $clog2(CACHE_SIZE)];
            is_dirty   <= meta[addr[OFFSET_WIDTH +: $clog2(CACHE_SIZE)]][DIRTY_BIT_POS];
            is_present <= meta[addr[OFFSET_WIDTH +: $clog2(CACHE_SIZE)]][PRESENT_BIT_POS];
            history    <= meta[addr[OFFSET_WIDTH +: $clog2(CACHE_SIZE)]][HISTORY_BITS_POS_START: HISTORY_BITS_POS_END];
            
            if( !is_rd && data_vld ) begin
                data_ <= data;
            end else if ( !is_rd && !data_vld ) begin
                $error("Not Expected, write with data not valid");
            end
            
            cache_busy_ <= 1'b1;
        end
    end
    
    always@(posedge clk) begin
        if( cache_busy_ && is_rd_ && !read_pending_ ) begin
            if( meta[cache_idx][META_DATA_WIDTH-1 -:TAG_WIDTH] == tag && is_present ) begin
                /* read hit */
                is_hit_ <= 1'b1;
                data_ <= mem[cache_idx][offset*DATA_WIDTH +: DATA_WIDTH];
                data_vld_ <= 1'b1;
                cache_busy_ <= 1'b0;
                read_pending_ <= 1'b0;
            end
            else if ( meta[cache_idx][META_DATA_WIDTH-1 -:TAG_WIDTH] != tag && is_present) begin
                /* read miss - cache line clean or dirty */
                data_     <= 'bx;
                data_vld_ <= 1'b1;
                is_hit_   <= 1'b0;
                cache_busy_ <= 1'b1;

                if( is_dirty ) begin
                    read_pending_ <= 1'b1;
                    addr_main_ <= {meta[cache_idx][META_DATA_WIDTH-1 -:TAG_WIDTH], cache_idx, offset};
                    addr_main_en_ <= 1'b1;
                    data_main_ <= mem[cache_idx];
                    data_main_vld_ <= 1'b1;
                end else begin
                    read_pending_ <= 1'b1;
                    addr_main_ <= addr_;
                    addr_main_en_ <= 1'b1;
                    data_main_ <= 'bx;
                    data_main_vld_ <= 1'b0;
                end
            end
            else begin // is_present == false
                /* read miss - cache line not in use */
                read_pending_ <= 1'b1;
                addr_main_ <= addr_;
                addr_main_en_ <= 1'b1;
                is_hit_ <= 1'b0;
                cache_busy_ <= 1'b1;
                data_ <= 'bx;
                data_vld_ <= 1'b0;
            end
        end else if( cache_busy_ && !is_rd_ && !write_pending_ ) begin
             if( meta[cache_idx][META_DATA_WIDTH-1 -:TAG_WIDTH] == tag && is_present ) begin
                /* write hit */
                is_hit_ <= 1'b1;
                mem[cache_idx][offset*DATA_WIDTH +: DATA_WIDTH] <= data_;
                cache_busy_ <= 1'b0;
                write_pending_ <= 1'b0;
                meta[cache_idx][DIRTY_BIT_POS] <= 1'b1;
                meta[cache_idx][PRESENT_BIT_POS] <= 1'b1;
            end 
            else if( meta[cache_idx][META_DATA_WIDTH-1 -:TAG_WIDTH] != tag && is_present )  begin
                /*write miss - cache line clean or dirty*/
                if(is_dirty) begin
                    write_pending_ <= 1'b1;
                    is_hit_ <= 1'b0;
                    data_vld_ <= 1'b0;
                    cache_busy_ <= 1'b1;
                    addr_main_ <={meta[cache_idx][META_DATA_WIDTH-1 -:TAG_WIDTH], cache_idx, offset};
                    addr_main_en_ <= 1'b1;
                    data_main_ <= mem[cache_idx];
                    data_main_vld_ <= 1'b1;
                end else begin
                    is_hit_ <= 1'b0;
                    data_vld_ <= 1'b0;
                    data_ <= 'bx;
                    cache_busy_ <= 1'b0;
                    write_pending_ <= 1'b0;
                    mem[cache_idx][offset*DATA_WIDTH +: DATA_WIDTH] <= data_;
                    meta[cache_idx][DIRTY_BIT_POS] <= 1'b1;
                    meta[cache_idx][META_DATA_WIDTH-1 -: TAG_WIDTH] <= tag;
                end
            end
            else begin    // is_present == false
                /* write miss cache line invalid*/
                write_pending_ <= 1'b0;
                cache_busy_ <= 1'b0;
                data_vld_ <= 1'b0;
                is_hit_ <= 1'b0;
                mem[cache_idx][offset*DATA_WIDTH +: DATA_WIDTH] <= data_;
                meta[cache_idx][DIRTY_BIT_POS] <= 1'b1;
                meta[cache_idx][META_DATA_WIDTH-1 -: TAG_WIDTH] <= tag;
                meta[cache_idx][PRESENT_BIT_POS] <= 1'b1;
            end
        end
        else if (cache_busy_ && read_pending_) begin
            if(is_dirty && is_present) begin
                //$display("Evicted address %h", addr_main_);
                is_dirty <= 1'b0;
                read_pending_ <= 1'b1;
                cache_busy_ <= 1'b1;
                addr_main_ <= addr_;
                addr_main_en_ <= 1'b1;
                data_main_ <= 'bx;
                data_main_vld_ <= 1'b0;
            end else begin
                read_pending_ <= 1'b0;
                cache_busy_ <= 1'b0;
                data_ <= data_main_[offset*DATA_WIDTH +: DATA_WIDTH];
                data_vld_ <= 1'b1;
                mem[cache_idx] <= data_main_;
                meta[cache_idx][DIRTY_BIT_POS] <= 1'b0;
                meta[cache_idx][META_DATA_WIDTH-1 -: TAG_WIDTH] <= tag;
                meta[cache_idx][PRESENT_BIT_POS] <= 1'b1;
            end
        end
        else if (cache_busy_ && write_pending_ ) begin
            if (is_dirty) begin
                //$display("Evicted address %h", addr_main_);
                is_dirty <= 1'b0;
                write_pending_ <= 1'b1;
                cache_busy_ <= 1'b1;
                write_extra_cycle_ <= 1'b1;
                addr_main_ <= addr_;
                addr_main_en_ <= 1'b1;
                data_main_ <= 'bx;
                data_main_vld_ <= 1'b0;
            end else if (write_extra_cycle_) begin
                write_pending_ <= 1'b1;
                cache_busy_ <= 1'b1;
                write_extra_cycle_ <= 1'b0;
                mem[cache_idx] <= data_main_;
                meta[cache_idx][DIRTY_BIT_POS] <= 1'b0;
                meta[cache_idx][META_DATA_WIDTH-1 -: TAG_WIDTH] <= tag;
                meta[cache_idx][PRESENT_BIT_POS] <= 1'b1;
            end else begin
                write_pending_ <= 1'b0;
                cache_busy_ <= 1'b0;
                mem[cache_idx][offset*DATA_WIDTH +: DATA_WIDTH] <= data_;
                meta[cache_idx][DIRTY_BIT_POS] <= 1'b1;
            end
        end
    end
    
    always@(posedge clk) begin
        if( flush ) begin
            mem <= 'b0;
            meta <= 'b0;
            write_pending_ <= 1'b0;
            read_pending_  <= 1'b0;
            cache_busy_ <= 1'b0;
            is_hit_ <= 1'b0;
            data_vld_ <= 1'b0;
            data_ <= 'b0;
            tag <= 'b0;
            history <= 'b0;
            write_extra_cycle_ = 1'b0;
            cache_idx <= 'b0;
            is_dirty <= 'b0;
            is_present <= 'b0;
            addr_main_en_ <= 'b0;
            addr_main_ <= 'b0;
            data_main_vld_ <= 'b0;
            data_main_ <= 'b0;
        end
    end
/*
        if( !cache_busy_ && !addr_en ) begin
            write_pending_ <= 1'b0;
            read_pending_  <= 1'b0;
            cache_busy_ <= 1'b0;
            is_hit_ <= 1'b0;
            data_vld_ <= 1'b0;
            data_ <= 'bx;
            tag <= 'bx;
            history <= 'bx;
            write_extra_cycle_ <= 1'bx;
            cache_idx <= 'bx;
            is_dirty <= 'bx;
            is_present <= 'bx;
            addr_main_en_ <= 'bx;
            addr_main_ <= 'bx;
            data_main_vld_ <= 'bx;
            data_main_ <= 'bx;
        end 
    end
*/ 
    
    // Setting outputs
    //**************************************
    assign cache_busy = cache_busy_;
    assign is_hit     = is_hit_;
    assign data       = data_vld_ ? data_ : 'bz;
    assign data_main  = data_main_;
    assign data_main_vld = data_main_vld_;
    assign addr_main  = addr_main_;
    assign addr_main_en = addr_main_en_;
    assign data_vld_out = data_vld_;
endmodule

