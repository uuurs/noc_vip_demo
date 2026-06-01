// noc_perf_sample.sv - Single performance sample
class noc_perf_sample extends uvm_object;

    realtime     timestamp;
    realtime     latency;
    real         throughput_mbps;
    real         bandwidth_mbps;
    int          outstanding_depth;
    int          total_read_bytes;
    int          total_write_bytes;
    int          read_count;
    int          write_count;
    int          window_size;

    `uvm_object_utils(noc_perf_sample)

    function new(string name = "noc_perf_sample");
        super.new(name);
        timestamp        = 0;
        latency          = 0;
        throughput_mbps  = 0.0;
        bandwidth_mbps   = 0.0;
        outstanding_depth = 0;
        total_read_bytes  = 0;
        total_write_bytes = 0;
        read_count       = 0;
        write_count      = 0;
        window_size      = 0;
    endfunction

    function string to_csv();
        return $sformatf("%0t,%0t,%.2f,%.2f,%0d,%0d,%0d,%0d,%0d,%0d",
            timestamp, latency, throughput_mbps, bandwidth_mbps,
            outstanding_depth, total_read_bytes, total_write_bytes,
            read_count, write_count, window_size);
    endfunction

    static function string csv_header();
        return "timestamp,avg_latency,throughput_mbps,bandwidth_mbps,outstanding,total_rd_bytes,total_wr_bytes,rd_count,wr_count,window";
    endfunction
endclass
