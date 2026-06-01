// noc_perf_monitor.sv - Performance monitor: latency, throughput, bandwidth, outstanding
class noc_perf_monitor extends uvm_subscriber #(noc_unified_transaction);

    `uvm_component_utils(noc_perf_monitor)

    noc_env_cfg     m_cfg;

    // Latency tracking per slave per master
    realtime        m_total_latency;
    realtime        m_min_latency;
    realtime        m_max_latency;
    int             m_latency_samples;

    // Throughput / bandwidth tracking
    int             m_total_bytes;
    realtime        m_first_txn_time;
    realtime        m_last_txn_time;
    realtime        m_window_start_time;
    int             m_window_bytes;
    int             m_window_txns;
    real            m_instant_throughput;
    real            m_average_bandwidth;

    // Outstanding tracking
    int             m_current_outstanding;
    int             m_max_outstanding;
    int             m_outstanding_samples;

    // Per-slave tracking
    realtime        m_slave_latency[`NOC_MAX_SLAVES];
    int             m_slave_txns[`NOC_MAX_SLAVES];
    int             m_slave_bytes[`NOC_MAX_SLAVES];

    // Performance samples
    noc_perf_sample m_samples[$];
    int             m_sample_count;
    int             m_perf_fd;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_total_latency     = 0;
        m_min_latency       = 0;
        m_max_latency       = 0;
        m_latency_samples   = 0;
        m_total_bytes       = 0;
        m_first_txn_time    = 0;
        m_last_txn_time     = 0;
        m_window_bytes      = 0;
        m_window_txns       = 0;
        m_current_outstanding = 0;
        m_max_outstanding    = 0;
        m_outstanding_samples = 0;
        m_sample_count      = 0;
        m_instant_throughput = 0.0;
        m_average_bandwidth  = 0.0;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(noc_env_cfg)::get(this, "", "noc_env_cfg", m_cfg))
            `uvm_fatal("NOC_PERF", "Failed to get noc_env_cfg from config_db")

        for (int i = 0; i < `NOC_MAX_SLAVES; i++) begin
            m_slave_latency[i] = 0;
            m_slave_txns[i] = 0;
            m_slave_bytes[i] = 0;
        end
    endfunction

    function void start_of_simulation_phase(uvm_phase phase);
        super.start_of_simulation_phase(phase);
        m_perf_fd = $fopen("logs/noc_perf.csv", "w");
        if (m_perf_fd)
            $fdisplay(m_perf_fd, "%s", noc_perf_sample::csv_header());
    endfunction

    virtual function void write(noc_unified_transaction t);
        realtime latency = t.get_latency();

        // Initialize time reference
        if (m_first_txn_time == 0)
            m_first_txn_time = t.start_time;
        m_last_txn_time = t.end_time;

        // Latency tracking
        m_total_latency += latency;
        m_latency_samples++;
        if (latency < m_min_latency || m_min_latency == 0) m_min_latency = latency;
        if (latency > m_max_latency) m_max_latency = latency;

        // Per-slave latency
        if (t.slave_id >= 0 && t.slave_id < `NOC_MAX_SLAVES) begin
            m_slave_latency[t.slave_id] += latency;
            m_slave_txns[t.slave_id]++;
            m_slave_bytes[t.slave_id] += t.get_transfer_bytes();
        end

        // Throughput/bandwidth
        int txn_bytes = t.get_transfer_bytes();
        m_total_bytes += txn_bytes;
        m_window_bytes += txn_bytes;
        m_window_txns++;

        // Outstanding depth
        m_current_outstanding++;
        if (t.last || t.resp != noc_unified_transaction::RESP_OKAY) begin
            if (m_current_outstanding > 0) m_current_outstanding--;
        end
        if (m_current_outstanding > m_max_outstanding)
            m_max_outstanding = m_current_outstanding;
        m_outstanding_samples++;

        // Check if window expired (sample interval)
        if ((t.end_time - m_window_start_time) >= (m_cfg.perf_sample_window * 1ns)) begin
            capture_sample();
            m_window_bytes = 0;
            m_window_txns = 0;
            m_window_start_time = t.end_time;
        end
    endfunction

    function void capture_sample();
        noc_perf_sample s = noc_perf_sample::type_id::create();
        s.timestamp         = $realtime;
        s.latency           = (m_latency_samples > 0) ? (m_total_latency / m_latency_samples) : 0;
        s.outstanding_depth = m_max_outstanding;
        s.total_read_bytes  = m_total_bytes;  // simplified, actual tracks r/w separately
        s.total_write_bytes = m_total_bytes;
        s.window_size       = m_cfg.perf_sample_window;
        s.throughput_mbps   = (m_last_txn_time > m_first_txn_time) ?
            (real'(m_total_bytes) * 8.0 / 1000000.0) /
            (real'(m_last_txn_time - m_first_txn_time) / 1e9) : 0.0;
        s.bandwidth_mbps    = s.throughput_mbps;  // bandwidth = throughput for single channel
        m_samples.push_back(s);
        m_sample_count++;

        if (m_perf_fd)
            $fdisplay(m_perf_fd, "%s", s.to_csv());
    endfunction

    function real get_average_latency();
        if (m_latency_samples == 0) return 0.0;
        return real'(m_total_latency) / real'(m_latency_samples);
    endfunction

    function real get_throughput_mbps();
        realtime elapsed = m_last_txn_time - m_first_txn_time;
        if (elapsed == 0) return 0.0;
        return (real'(m_total_bytes) * 8.0 / 1000000.0) / (real'(elapsed) / 1e9);
    endfunction

    function void extract_phase(uvm_phase phase);
        super.extract_phase(phase);
        if (m_window_bytes > 0) capture_sample();
        if (m_perf_fd) $fclose(m_perf_fd);
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("NOC_PERF", "\n=== NOC Performance Report ===", UVM_LOW)
        `uvm_info("NOC_PERF", $sformatf("Avg Latency:      %0.2f ns", get_average_latency()), UVM_LOW)
        `uvm_info("NOC_PERF", $sformatf("Min Latency:      %0t", m_min_latency), UVM_LOW)
        `uvm_info("NOC_PERF", $sformatf("Max Latency:      %0t", m_max_latency), UVM_LOW)
        `uvm_info("NOC_PERF", $sformatf("Throughput:       %.2f Mbps", get_throughput_mbps()), UVM_LOW)
        `uvm_info("NOC_PERF", $sformatf("Total Bytes:      %0d", m_total_bytes), UVM_LOW)
        `uvm_info("NOC_PERF", $sformatf("Max Outstanding:  %0d", m_max_outstanding), UVM_LOW)
        `uvm_info("NOC_PERF", $sformatf("Total Txns:       %0d", m_latency_samples), UVM_LOW)
        `uvm_info("NOC_PERF", $sformatf("Samples captured: %0d (window=%0dns)", m_sample_count, m_cfg.perf_sample_window), UVM_LOW)

        // Per-slave breakdown
        for (int i = 0; i < m_cfg.num_slaves; i++) begin
            if (m_slave_txns[i] > 0) begin
                `uvm_info("NOC_PERF", $sformatf("  Slave[%0d] %s: %0d txns, %0d bytes, avg lat %0t",
                    i, m_cfg.slaves[i].name, m_slave_txns[i], m_slave_bytes[i],
                    m_slave_latency[i] / m_slave_txns[i]), UVM_LOW)
            end
        end
        `uvm_info("NOC_PERF", "===================================\n", UVM_LOW)
    endfunction
endclass
