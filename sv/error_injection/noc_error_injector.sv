// noc_error_injector.sv - Error injection component
class noc_error_injector extends uvm_component;

    `uvm_component_utils(noc_error_injector)

    typedef enum bit [2:0] {
        ERR_ILLEGAL_ADDR      = `NOC_ERR_ILLEGAL_ADDR,
        ERR_ILLEGAL_BURST     = `NOC_ERR_ILLEGAL_BURST,
        ERR_TIMEOUT           = `NOC_ERR_TIMEOUT,
        ERR_DECERR            = `NOC_ERR_DECERR,
        ERR_SLVERR            = `NOC_ERR_SLVERR,
        ERR_BOUNDARY_VIOLATION = `NOC_ERR_BOUNDARY_VIOLATION
    } error_type_e;

    noc_env_cfg     m_cfg;

    // Injection control
    bit             m_inject_enable;
    error_type_e    m_current_error;
    int             m_error_count;
    int             m_error_interval;    // inject every N transactions
    int             m_txn_since_last_err;

    // Injection targets
    bit [63:0]      m_error_addr;
    int             m_error_master_id;
    int             m_error_slave_id;
    realtime        m_timeout_delay;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        m_inject_enable      = 1'b0;
        m_current_error      = ERR_DECERR;
        m_error_count        = 0;
        m_error_interval     = 100;
        m_txn_since_last_err = 0;
        m_error_addr         = 64'hDEAD_BEEF;
        m_error_master_id    = 0;
        m_error_slave_id     = 0;
        m_timeout_delay      = 10000ns;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(noc_env_cfg)::get(this, "", "noc_env_cfg", m_cfg))
            `uvm_fatal("NOC_ERR_INJ", "Failed to get noc_env_cfg from config_db")
    endfunction

    // Configure injection parameters
    function void set_error(error_type_e err, int interval = 100, bit enable = 1'b1);
        m_current_error   = err;
        m_error_interval  = interval;
        m_inject_enable   = enable;
    endfunction

    function void set_error_target(bit [63:0] addr, int master_id = 0, int slave_id = 0);
        m_error_addr      = addr;
        m_error_master_id = master_id;
        m_error_slave_id  = slave_id;
    endfunction

    // Inject error into a transaction before it goes to driver
    function bit inject(noc_unified_transaction txn);
        if (!m_inject_enable) return 1'b0;

        m_txn_since_last_err++;
        if (m_txn_since_last_err < m_error_interval) return 1'b0;

        m_txn_since_last_err = 0;
        m_error_count++;

        case (m_current_error)
            ERR_ILLEGAL_ADDR: begin
                txn.addr = m_error_addr;
                `uvm_info("NOC_ERR_INJ", $sformatf("Injected illegal address: 0x%0h", m_error_addr), UVM_MEDIUM)
            end

            ERR_ILLEGAL_BURST: begin
                txn.burst = noc_unified_transaction::WRAP;
                txn.len   = 8'hFF;
                `uvm_info("NOC_ERR_INJ", "Injected illegal burst type/length", UVM_MEDIUM)
            end

            ERR_TIMEOUT: begin
                txn.start_time = $realtime - m_timeout_delay - 1ns;
                `uvm_info("NOC_ERR_INJ", $sformatf("Injected timeout (delay=%0t)", m_timeout_delay), UVM_MEDIUM)
            end

            ERR_DECERR: begin
                txn.resp = noc_unified_transaction::RESP_DECERR;
                `uvm_info("NOC_ERR_INJ", "Injected DECERR response", UVM_MEDIUM)
            end

            ERR_SLVERR: begin
                txn.resp = noc_unified_transaction::RESP_SLVERR;
                `uvm_info("NOC_ERR_INJ", "Injected SLVERR response", UVM_MEDIUM)
            end

            ERR_BOUNDARY_VIOLATION: begin
                // Force addr near 4KB boundary for a burst that will cross
                txn.addr = 64'hFFF0;  // 16 bytes before 4KB boundary
                txn.len  = 8'h01;     // 2 beats will cross
                txn.size = 3'h3;      // 8 bytes each = 16 total, crosses at 4KB
                `uvm_info("NOC_ERR_INJ", "Injected boundary violation (4KB crossing)", UVM_MEDIUM)
            end
        endcase
        return 1'b1;
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("NOC_ERR_INJ", $sformatf("Error Injector: %0d errors injected (type=%0s)",
            m_error_count, error_name()), UVM_LOW)
    endfunction

    function string error_name();
        case (m_current_error)
            ERR_ILLEGAL_ADDR:       return "ILLEGAL_ADDR";
            ERR_ILLEGAL_BURST:      return "ILLEGAL_BURST";
            ERR_TIMEOUT:            return "TIMEOUT";
            ERR_DECERR:             return "DECERR";
            ERR_SLVERR:             return "SLVERR";
            ERR_BOUNDARY_VIOLATION: return "BOUNDARY_VIOLATION";
            default:                return "UNKNOWN";
        endcase
    endfunction
endclass
