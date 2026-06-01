// noc_virtual_sequencer.sv - Coordinates multi-master traffic
class noc_virtual_sequencer extends uvm_sequencer;

    `uvm_component_utils(noc_virtual_sequencer)

    // Handles to each master's unified sequencer
    noc_unified_sequencer   m_master_seqr[`NOC_MAX_MASTERS];

    // API wrapper reference (for noc_read/noc_write calls)
    noc_api_wrapper         m_api;

    noc_env_cfg             m_cfg;
    int                     m_num_masters;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(noc_env_cfg)::get(this, "", "noc_env_cfg", m_cfg))
            `uvm_fatal("NOC_VSEQR", "Failed to get noc_env_cfg from config_db")
        m_num_masters = m_cfg.num_masters;
    endfunction

    // Execute a single transaction through the appropriate master
    task execute_single(noc_unified_transaction txn);
        noc_slave_config slave_cfg = m_cfg.find_slave_by_addr(txn.addr);
        if (slave_cfg == null) begin
            txn.resp = noc_unified_transaction::RESP_DECERR;
            `uvm_warning("NOC_VSEQR", $sformatf("No slave mapped to addr=0x%0h", txn.addr))
            return;
        end

        // Route to first master that supports this protocol
        for (int i = 0; i < m_num_masters; i++) begin
            noc_master_config mst_cfg = m_cfg.find_master_by_id(i);
            if (mst_cfg != null && mst_cfg.protocol == txn.protocol_name()) begin
                txn.master_id = i;
                txn.slave_id  = slave_cfg.slave_id;
                txn.slave_name = slave_cfg.name;
                txn.start_time = $realtime;
                m_master_seqr[i].wait_for_grant(txn);
                // In real use, start the item on the sequencer
                txn.end_time = $realtime;
                return;
            end
        end
        `uvm_warning("NOC_VSEQR", $sformatf("No master found for protocol=%s", txn.protocol_name()))
    endtask

    // Execute a list of transactions in parallel across masters
    task execute_parallel(noc_unified_transaction txns[$]);
        fork
            foreach (txns[i])
                execute_single(txns[i]);
        join
    endtask
endclass
