// noc_txn_logger.sv - Transaction logger with CSV and JSON output
class noc_txn_logger extends uvm_subscriber #(noc_unified_transaction);

    `uvm_component_utils(noc_txn_logger)

    noc_env_cfg     m_cfg;
    int             m_csv_fd;
    int             m_json_fd;
    int             m_txn_count;
    bit             m_header_written;
    bit             m_first_json_entry;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_csv_fd = 0;
        m_json_fd = 0;
        m_txn_count = 0;
        m_header_written = 1'b0;
        m_first_json_entry = 1'b1;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(noc_env_cfg)::get(this, "", "noc_env_cfg", m_cfg))
            `uvm_fatal("NOC_LOGGER", "Failed to get noc_env_cfg from config_db")
    endfunction

    function void start_of_simulation_phase(uvm_phase phase);
        super.start_of_simulation_phase(phase);

        if (m_cfg.log_format == `NOC_LOG_FMT_CSV || m_cfg.log_format == `NOC_LOG_FMT_BOTH) begin
            m_csv_fd = $fopen(m_cfg.log_csv_path, "w");
            if (m_csv_fd) begin
                $fdisplay(m_csv_fd, "%s", noc_txn_record::csv_header());
                `uvm_info("NOC_LOGGER", $sformatf("CSV log opened: %s", m_cfg.log_csv_path), UVM_MEDIUM)
            end
        end

        if (m_cfg.log_format == `NOC_LOG_FMT_JSON || m_cfg.log_format == `NOC_LOG_FMT_BOTH) begin
            m_json_fd = $fopen(m_cfg.log_json_path, "w");
            if (m_json_fd) begin
                $fdisplay(m_json_fd, "{\n  \"noc_name\": \"%s\",\n  \"transactions\": [", m_cfg.noc_name);
                `uvm_info("NOC_LOGGER", $sformatf("JSON log opened: %s", m_cfg.log_json_path), UVM_MEDIUM)
            end
        end
    endfunction

    virtual function void write(noc_unified_transaction t);
        noc_txn_record rec = noc_txn_record::from_txn(t);
        m_txn_count++;

        // CSV output
        if (m_csv_fd)
            $fdisplay(m_csv_fd, "%s", rec.to_csv());

        // JSON output
        if (m_json_fd) begin
            if (!m_first_json_entry)
                $fdisplay(m_json_fd, ",");
            $fwrite(m_json_fd, "    %s", rec.to_json());
            m_first_json_entry = 1'b0;
        end

        `uvm_info("NOC_LOGGER", $sformatf("Txn #%0d: %s", m_txn_count, t.convert2string()), UVM_HIGH)
    endfunction

    function void extract_phase(uvm_phase phase);
        super.extract_phase(phase);

        if (m_json_fd) begin
            $fdisplay(m_json_fd, "\n  ],\n  \"total_transactions\": %0d\n}", m_txn_count);
            $fclose(m_json_fd);
            `uvm_info("NOC_LOGGER", $sformatf("JSON log written: %s (%0d txns)",
                m_cfg.log_json_path, m_txn_count), UVM_MEDIUM)
        end

        if (m_csv_fd) begin
            $fclose(m_csv_fd);
            `uvm_info("NOC_LOGGER", $sformatf("CSV log written: %s (%0d txns)",
                m_cfg.log_csv_path, m_txn_count), UVM_MEDIUM)
        end
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("NOC_LOGGER", $sformatf("Total transactions logged: %0d", m_txn_count), UVM_LOW)
    endfunction
endclass
