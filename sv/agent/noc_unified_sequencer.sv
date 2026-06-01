// noc_unified_sequencer.sv - Protocol-agnostic unified sequencer
class noc_unified_sequencer extends uvm_sequencer #(noc_unified_transaction);

    `uvm_component_utils(noc_unified_sequencer)

    // Associated SVT VIP sequencers for protocol routing
    uvm_sequencer_base  m_svt_sequencers[`NOC_MAX_MASTERS];
    int                 m_master_id;
    string              m_master_name;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction

    // Register a SVT sequencer for a given master id
    function void register_svt_sequencer(int master_id, uvm_sequencer_base seqr);
        m_svt_sequencers[master_id] = seqr;
        `uvm_info(get_name(), $sformatf("Registered SVT sequencer for master[%0d]", master_id), UVM_MEDIUM)
    endfunction

    function uvm_sequencer_base get_svt_sequencer(int master_id);
        return m_svt_sequencers[master_id];
    endfunction
endclass
