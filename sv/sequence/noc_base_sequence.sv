// noc_base_sequence.sv - Base sequence with constraint override points
class noc_base_sequence extends uvm_sequence #(noc_unified_transaction);

    `uvm_object_utils(noc_base_sequence)

    noc_env_cfg  m_cfg;

    // Overridable constraint variables
    rand bit [63:0]                      target_addr;
    rand noc_unified_transaction::direction_e  target_direction;
    rand noc_unified_transaction::burst_type_e target_burst;
    rand bit [7:0]                       burst_len;
    rand bit [2:0]                       data_size;
    rand bit [15:0]                      txn_id;
    rand bit [3:0]                       txn_qos;
    rand bit [3:0]                       txn_cache;
    rand bit [2:0]                       txn_prot;
    rand bit                             txn_lock;
    rand bit [31:0]                      txn_user;

    // Default constraints - user overrides via inheritance
    constraint c_default_addr  { target_addr inside {[64'h0 : 64'hFFFF_FFFF]}; }
    constraint c_default_len   { burst_len inside {[0:15]}; }
    constraint c_default_size  { data_size inside {[0:7]}; }
    constraint c_default_id    { txn_id inside {[0:15]}; }
    constraint c_default_qos   { txn_qos == 0; }
    constraint c_default_prot  { txn_prot == 3'b000; }
    constraint c_default_lock  { txn_lock == 1'b0; }
    constraint c_default_cache { txn_cache == 4'b0000; }

    function new(string name = "noc_base_sequence");
        super.new(name);
        target_direction = noc_unified_transaction::NOC_READ;
        target_burst     = noc_unified_transaction::INCR;
        burst_len        = 8'h0;
        data_size        = 3'h2;
        txn_id           = 16'h0;
        txn_qos          = 4'h0;
        txn_cache        = 4'h0;
        txn_prot         = 3'h0;
        txn_lock         = 1'b0;
        txn_user         = 32'h0;
    endfunction

    // Get config from DB if available
    task pre_body();
        if (m_cfg == null) begin
            if (!uvm_config_db #(noc_env_cfg)::get(null, get_full_name(), "noc_env_cfg", m_cfg))
                `uvm_info("NOC_SEQ", "No noc_env_cfg in config_db, using default constraints", UVM_MEDIUM)
            else begin
                // Update addr constraint with valid ranges from config
                c_default_addr.constraint_mode(0);
            end
        end
    endtask

    task body();
        noc_unified_transaction txn;
        `uvm_do_with(txn, {
            addr      == target_addr;
            direction == target_direction;
            burst     == target_burst;
            len       == burst_len;
            size      == data_size;
            id        == txn_id;
            qos       == txn_qos;
            cache     == txn_cache;
            prot      == txn_prot;
            lock      == txn_lock;
            user      == txn_user;
        })
        `uvm_info("NOC_SEQ", $sformatf("Generated: %s", txn.convert2string()), UVM_MEDIUM)
    endtask
endclass
