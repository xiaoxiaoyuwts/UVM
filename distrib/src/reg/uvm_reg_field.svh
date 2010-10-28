//
// -------------------------------------------------------------
//    Copyright 2004-2009 Synopsys, Inc.
//    Copyright 2010 Mentor Graphics Corp.
//    All Rights Reserved Worldwide
//
//    Licensed under the Apache License, Version 2.0 (the
//    "License"); you may not use this file except in
//    compliance with the License.  You may obtain a copy of
//    the License at
//
//        http://www.apache.org/licenses/LICENSE-2.0
//
//    Unless required by applicable law or agreed to in
//    writing, software distributed under the License is
//    distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
//    CONDITIONS OF ANY KIND, either express or implied.  See
//    the License for the specific language governing
//    permissions and limitations under the License.
// -------------------------------------------------------------
//

//
// Title: Register Field Abstraction Base Classes
//
// A field is an atomic value in the DUT and
// are wholly contained in a register.
// All bits in a field have the same access policy.
//
// <uvm_reg_field> : base for abstract register fields
//
// <uvm_reg_field_cbs> : base for user-defined pre/post read/write callbacks
//


typedef class uvm_reg_field_cbs;


//-----------------------------------------------------------------
// CLASS: uvm_reg_field
// Field abstraction class
//
// A field represents a set of bits that behave consistently
// as a single entity.
//
// A field is contained within a single register, but may
// have different access policies depending on the adddress map
// use the access the register (thus the field).
//-----------------------------------------------------------------
class uvm_reg_field extends uvm_object;

   local static int m_max_size = 0;
   local static bit m_policy_names[string];
   local string access;
   local bit m_volatile;
   local uvm_reg parent;
   local int unsigned lsb;
   local int unsigned size;
   local uvm_reg_data_t  mirrored; // What we think is in the HW
   local uvm_reg_data_t  desired;  // Mirrored after set()
   rand  uvm_reg_data_t  value;    // Mirrored after randomize()
   local uvm_reg_data_t  m_reset[string];
   local bit written;
   local bit read_in_progress;
   local bit write_in_progress;
   local string fname = "";
   local int lineno = 0;
   local int cover_on;
   local bit individually_accessible = 0;
   local string attributes[string];


   constraint uvm_reg_field_valid {
      if (`UVM_REG_DATA_WIDTH > size) {
         value < (`UVM_REG_DATA_WIDTH'h1 << size);
      }
   }

   `uvm_object_utils(uvm_reg_field)

   //----------------------
   // Group: Initialization
   //----------------------

   //------------------------------------------------------------------------
   // FUNCTION: new
   // Create a new field instance
   //
   // This method should not be used directly.
   // The uvm_reg_field::type_id::create() method shoudl be used instead.
   //------------------------------------------------------------------------
   extern function new(string name = "uvm_reg_field");

   //
   // Function: configure
   // Instance-specific configuration
   //
   // Specify the ~parent~ register of this field, its
   // ~size~ in bits, the position of its least-significant bit
   // within the register relative to the least-significant bit
   // of the register, its ~access~ policy, volatility,
   // "HARD" ~reset~ value, 
   // whether the field value may be randomized and
   // whether the field is the only one to occupy a byte lane in the register.
   //
   // See <set_access> for a specification of the pre-defined
   // field access policies.
   //
   extern function void configure(uvm_reg        parent,
                                  int unsigned   size,
                                  int unsigned   lsb_pos,
                                  string         access,
                                  bit            volatile,
                                  uvm_reg_data_t reset,
                                  bit            is_rand,
                                  bit            individually_accessible); 


   //---------------------
   // Group: Introspection
   //---------------------

   //
   // Function: get_name
   // Get the simple name
   //
   // Return the simple object name of this field
   //

   //
   // Function: get_full_name
   // Get the hierarchical name
   //
   // Return the hierarchal name of this field
   // The base of the hierarchical name is the root block.
   //
   extern virtual function string        get_full_name();

   //
   // FUNCTION: get_parent
   // Get the parent register
   //
   extern virtual function uvm_reg get_parent ();
   extern virtual function uvm_reg get_register  ();

   //
   // FUNCTION: get_lsb_pos_in_register
   // Return the position of the field
   ///
   // Returns the index of the least significant bit of the field
   // in the register that instantiates it.
   // An offset of 0 indicates a field that is aligned with the
   // least-significant bit of the register. 
   //
   extern virtual function int unsigned get_lsb_pos_in_register();

   //
   // FUNCTION: get_n_bits
   // Returns the width, in number of bits, of the field. 
   //
   extern virtual function int unsigned get_n_bits();

   //
   // FUNCTION: get_max_size
   // Returns the width, in number of bits, of the largest field. 
   //
   extern static function int unsigned get_max_size();


   //
   // FUNCTION: set_access
   // Modify the access policy of the field
   //
   // Modify the access policy of the field to the specified one and
   // return the previous access policy.
   //
   // The pre-defined access policies are as follows.
   // The effect of a read operation are applied after the current
   // value of the field is sampled.
   // The read operation will return the current value,
   // not the value affected by the read operation (if any).
   //
   // "RO"    - W: no effect, R: no effect
   // "RW"    - W: as-is, R: no effect
   // "RC"    - W: no effect, R: clears all bits
   // "RS"    - W: no effect, R: sets all bits
   // "WRC"   - W: as-is, R: clears all bits
   // "WRS"   - W: as-is, R: sets all bits
   // "WC"    - W: clears all bits, R: no effect
   // "WS"    - W: sets all bits, R: no effect
   // "WSRC"  - W: sets all bits, R: clears all bits
   // "WCRS"  - W: clears all bits, R: sets all bits
   // "W1C"   - W: 1/0 clears/no effect on matching bit, R: no effect
   // "W1S"   - W: 1/0 sets/no effect on matching bit, R: no effect
   // "W1T"   - W: 1/0 toggles/no effect on matching bit, R: no effect
   // "W0C"   - W: 1/0 no effect on/clears matching bit, R: no effect
   // "W0S"   - W: 1/0 no effect on/sets matching bit, R: no effect
   // "W0T"   - W: 1/0 no effect on/toggles matching bit, R: no effect
   // "W1SRC" - W: 1/0 sets/no effect on matching bit, R: clears all bits
   // "W1CRS" - W: 1/0 clears/no effect on matching bit, R: sets all bits
   // "W0SRC" - W: 1/0 no effect on/sets matching bit, R: clears all bits
   // "W0CRS" - W: 1/0 no effect on/clears matching bit, R: sets all bits
   // "WO"    - W: as-is, R: error
   // "WOC"   - W: clears all bits, R: error
   // "WOS"   - W: sets all bits, R: error
   // "W1"    - W: first one after ~HARD~ reset is as-is, other W have no effects, R: no effect
   // "WO1"   - W: first one after ~HARD~ reset is as-is, other W have no effects, R: error
   // "DC"    - W: as-is, R: no effect but "check" never fails
   //
   // It is important to remember that modifying the access of a field
   // will make the register model diverge from the specification
   // that was used to create it.
   //
   extern virtual function string       set_access(string mode);

   //
   // Function: define_access
   // Define a new access policy value
   //
   // Because field access policies are specified using string values,
   // there is no way for SystemVerilog to verify if a spceific access
   // value is valid or not.
   // To help catch typing errors, user-defined access values
   // must be defined using this method to avoid beign reported as an
   // invalid access policy.
   //
   // The name of field access policies are always converted to all uppercase.
   //
   // Returns TRUE if the new access policy was not previously
   // defined.
   // Returns FALSE otherwise but does not issue an error message.
   //
   extern static function bit define_access(string name);
   local static bit m_predefined = m_predefine_policies();
   extern local static function bit m_predefine_policies();
 
   //
   // FUNCTION: get_access
   // Get the access policy of the field
   //
   // Returns the current access policy of the field
   // when written and read through the specified address ~map~.
   // If the register containing the field is mapped in multiple
   // address map, an address map must be specified.
   // The access policy of a field from a specific
   // address map may be restricted by the register's access policy in that
   // address map.
   // For example, a RW field may only be writable through one of
   // the address maps and read-only through all of the other maps.
   //
   extern virtual function string       get_access(uvm_reg_map map = null);

   //
   // FUNCTION: is_known_access
   // Check if access policy is a built-in one.
   //
   // Returns TRUE if the current access policy of the field,
   // when written and read through the specified address ~map~,
   // is a built-in access policy.
   //
   extern virtual function bit          is_known_access(uvm_reg_map map = null);

   //
   // FUNCTION: set_volatility
   // Modify the volatility of the field to the specified one.
   //
   // It is important to remember that modifying the volatility of a field
   // will make the register model diverge from the specification
   // that was used to create it.
   //
   extern virtual function void  set_volatility(bit volatile);

   //
   // FUNCTION: is_volatile
   // Indicates if the field value is volatile
   //
   // If TRUE, the value of the register is not predictable because it
   // may change between consecutive accesses.
   // This typically indicates a field whose value is updated by the DUT.
   // The nature or cause of the change is not specified.
   // If FALSE, the value of the register is not modified between
   // consecutive accesses.
   //
   extern virtual function bit   is_volatile();


   //--------------
   // Group: Access
   //--------------


   //
   // FUNCTION: set
   // Set the desired value for this field
   //
   // Sets the desired value of the field to the specified value.
   // Does not actually set the value of the field in the design,
   // only the desired value in the abstrcation class.
   // Use the <uvm_reg::update()> method to update the actual register
   // with the desired value or the <uvm_reg_field::write()> method
   // to actually write the field and update its mirrored value.
   //
   // The final desired value in the mirror is a function of the field access
   // mode and the set value, just like a normal physical write operation
   // to the corresponding bits in the hardware.
   // As such, this method (when eventually followed by a call to
   // <uvm_reg::update()>)
   // is a zero-time functional replacement for the <uvm_reg_field::write()>
   // method.
   // For example, the mirrored value of a read-only field is not modified
   // by this method and the mirrored value of a write-once field can only
   // be set if the field has not yet been
   // written to using a physical (for example, front-door) write operation.
   //
   // Use the <uvm_reg_field::predict()> to modify the mirrored value of
   // the field.
   //
   extern virtual function void set(uvm_reg_data_t  value,
                                    string          fname = "",
                                    int             lineno = 0);

   //
   // FUNCTION: get
   // Return the desired value of the field
   //
   // Does not actually read the value
   // of the field in the design, only the desired value
   // in the abstraction class. Unless set to a different value
   // using the <uvm_reg_field::set()>, the desired value
   // and the mirrored value are identical.
   //
   // Use the <uvm_reg_field::read()> or <uvm_reg_field::peek()>
   // method to get the actual field value. 
   //
   // If the field is write-only, the desired/mirrored
   // value is the value last written and assumed
   // to reside in the bits implementing it.
   // Although a physical read operation would something different,
   // the returned value is the actual content.
   //
   extern virtual function uvm_reg_data_t get(string fname = "",
                                              int    lineno = 0);


   //
   // FUNCTION: reset
   // Reset the desired/mirrored value for this field.
   //
   // Sets the desired and mirror value of the field
   // to the reset event specified by ~kind~.
   // If the field does not have a reset value specified for the
   // specified reset ~kind~ the field is unchanged.
   //
   // Does not actually reset the value of the field in the design,
   // only the value mirrored in the field abstraction class.
   //
   // Write-once fields can be modified after
   // a "HARD" reset operation.
   //
   extern virtual function void reset(string kind = "HARD");

   //
   // FUNCTION: get_reset
   // Get the specified reset value for this field
   //
   // Return the reset value for this field
   // for the specified reset ~kind~.
   // Returns the current field value is no reset value has been
   // specified for the specified reset event.
   //
   extern virtual function uvm_reg_data_t 
                       get_reset(string kind = "HARD");

   //
   // FUNCTION: has_reset
   // Check if the field has a reset value specified
   //
   // Return TRUE if this field has a reset value specified
   // for the specified reset ~kind~.
   // If ~delete~ is TRUE, removes the reset value, if any.
   //
   extern virtual function bit has_reset(string kind = "HARD",
                                         bit    delete = 0);


   //
   // FUNCTION: set_reset
   // Specify or modify the reset value for this field
   //
   // Specify or modify the reset value for this field corresponding
   // to the cause specified by ~kind~.
   //
   extern virtual function void
                       set_reset(uvm_reg_data_t value,
                                 string         kind = "HARD");


   //
   // FUNCTION: needs_update
   // Check if the abstract model contains different desired and mirrored values.
   //
   // If a desired field value has been modified in the abstraction class
   // without actually updating the field in the DUT,
   // the state of the DUT (more specifically what the abstraction class
   // ~thinks~ the state of the DUT is) is outdated.
   // This method returns TRUE
   // if the state of the field in the DUT needs to be updated 
   // to match the desired value.
   // The mirror values or actual content of DUT field are not modified.
   // Use the <uvm_reg::update()> to actually update the DUT field.
   //
   extern virtual function bit needs_update();


   //
   // TASK: write
   // Write the specified value in this field
   //
   // Write ~value~ in the DUT field that corresponds to this
   // abstraction class instance using the specified access
   // ~path~. 
   // If the register containing this field is mapped in more
   //  than one address map, 
   // an address ~map~ must be
   // specified if a physical access is used (front-door access).
   // If a back-door access path is used, the effect of writing
   // the field through a physical access is mimicked. For
   // example, read-only bits in the field will not be written.
   //
   // The mirrored value will be updated using the <uvm_reg_field:predict()>
   // method.
   //
   // If a front-door access is used, and
   // if the field is the only field in a byte lane and
   // if the physical interface corresponding to the address map used
   // to access the field support byte-enabling,
   // then only the field is written.
   // Otherwise, the entire register containing the field is written,
   // and the mirrored values of the other fields in the same register
   // are used in a best-effort not to modify their value.
   //
   // If a backdoor access is used, a peek-modify-poke process is used.
   // in a best-effort not to modify the value of the other fields in the
   // register.
   //
   extern virtual task write (output uvm_status_e  status,
                              input  uvm_reg_data_t     value,
                              input  uvm_path_e    path = UVM_DEFAULT_PATH,
                              input  uvm_reg_map        map = null,
                              input  uvm_sequence_base  parent = null,
                              input  int                prior = -1,
                              input  uvm_object         extension = null,
                              input  string             fname = "",
                              input  int                lineno = 0);


   //
   // TASK: read
   // Read the current value from this field
   //
   // Read and return ~value~ from the DUT field that corresponds to this
   // abstraction class instance using the specified access
   // ~path~. 
   // If the register containing this field is mapped in more
   // than one address map, an address ~map~ must be
   // specified if a physical access is used (front-door access).
   // If a back-door access path is used, the effect of reading
   // the field through a physical access is mimicked. For
   // example, clear-on-read bits in the filed will be set to zero.
   //
   // The mirrored value will be updated using the <uvm_reg:predict()>
   // method.
   //
   // If a front-door access is used, and
   // if the field is the only field in a byte lane and
   // if the physical interface corresponding to the address map used
   // to access the field support byte-enabling,
   // then only the field is read.
   // Otherwise, the entire register containing the field is read,
   // and the mirrored values of the other fields in the same register
   // are updated.
   //
   // If a backdoor access is used, the entire containing register is peeked
   // and the mirrored value of the other fields in the register is updated.
   //
   extern virtual task read  (output uvm_status_e  status,
                              output uvm_reg_data_t     value,
                              input  uvm_path_e    path = UVM_DEFAULT_PATH,
                              input  uvm_reg_map        map = null,
                              input  uvm_sequence_base  parent = null,
                              input  int                prior = -1,
                              input  uvm_object         extension = null,
                              input  string             fname = "",
                              input  int                lineno = 0);
               

   //
   // TASK: poke
   // Deposit the specified value in this field
   //
   // Deposit the value in the DUT field corresponding to this
   // abstraction class instance, as-is, using a back-door access.
   // A peek-modify-poke process is used
   // in a best-effort not to modify the value of the other fields in the
   // register.
   //
   // The mirrored value will be updated using the <uvm_reg:predict()>
   // method.
   //
   extern virtual task poke  (output uvm_status_e  status,
                              input  uvm_reg_data_t     value,
                              input  string             kind = "",
                              input  uvm_sequence_base  parent = null,
                              input  uvm_object         extension = null,
                              input  string             fname = "",
                              input  int                lineno = 0);


   //
   // TASK: peek
   // Read the current value from this field
   //
   // Sample the value in the DUT field corresponding to this
   // absraction class instance using a back-door access.
   // The field value is sampled, not modified.
   //
   // Uses the HDL path for the design abstraction specified by ~kind~.
   //
   // The entire containing register is peeked
   // and the mirrored value of the other fields in the register
   // are updated using the <uvm_reg:predict()> method.
   //
   //
   extern virtual task peek  (output uvm_status_e  status,
                              output uvm_reg_data_t     value,
                              input  string             kind = "",
                              input  uvm_sequence_base  parent = null,
                              input  uvm_object         extension = null,
                              input  string             fname = "",
                              input  int                lineno = 0);
               

   //
   // TASK: mirror
   // Read the field and update/check its mirror value
   //
   // Read the field and optionally compared the readback value
   // with the current mirrored value if ~check~ is <UVM_VERB>.
   // The mirrored value will be updated using the <uvm_reg_field:predict()>
   // method based on the readback value.
   //
   // The mirroring can be performed using the physical interfaces (frontdoor)
   // or <uvm_reg_field::peek()> (backdoor).
   //
   // If ~check~ is specified as UVM_VERB,
   // an error message is issued if the current mirrored value
   // does not match the readback value, unless the field has the "DC"
   // (don't care) policy.
   //
   // If the containing register is mapped in multiple address maps and physical
   // access is used (front-door access), an address ~map~ must be specified.
   // For write-only fields, their content is mirrored and optionally
   // checked only if a UVM_BACKDOOR
   // access path is used to read the field. 
   //
   extern virtual task mirror(output uvm_status_e status,
                              input  uvm_check_e  check = UVM_NO_CHECK,
                              input  uvm_path_e   path = UVM_DEFAULT_PATH,
                              input  uvm_reg_map       map = null,
                              input  uvm_sequence_base parent = null,
                              input  int               prior = -1,
                              input  uvm_object        extension = null,
                              input  string            fname = "",
                              input  int               lineno = 0);


   //-----------------------------------------------------------------
   // FUNCTION: predict
   // Update the mirrored value for this field
   //
   // Predict the mirror value of the field
   // based on the specified observed ~value~ on a specified adress ~map~,
   // or based on a calculated value.
   //
   // If ~kind~ is specified as <UVM_PREDICT_READ>, the value
   // was observed in a read transaction on the specified address ~map~ or
   // backdoor (if ~path~ is <UVM_BACKDOOR>).
   // If ~kind~ is specified as <UVM_PREDICT_WRITE>, the value
   // was observed in a write transaction on the specified address ~map~ or
   // backdoor (if ~path~ is <UVM_BACKDOOR>).
   // If ~kind~ is specified as <UVM_PREDICT_DIRECT>, the value
   // was computed and is updated as-is, without reguard to any access policy.
   // For example, the mirrored value of a read-only field is modified
   // by this method if ~kind~ is specified as <UVM_PREDICT_DIRECT>.
   //
   // This method does not allow any explicit update of the mirror,
   // when the register containing this field is busy executing
   // a transaction because the results are unpredictable and
   // indicative of a race condition in the testbench.
   //
   // Returns TRUE if the prediction was succesful.
   extern virtual function bit predict (uvm_reg_data_t  value,
                                        uvm_predict_e kind = UVM_PREDICT_DIRECT,
                                        uvm_path_e path = UVM_BFM,
                                        uvm_reg_map     map = null,
                                        string          fname = "",
                                        int             lineno = 0);

   /*local*/ extern virtual function uvm_reg_data_t XpredictX (uvm_reg_data_t  cur_val,
        	                                               uvm_reg_data_t  wr_val,
                                                               uvm_reg_map  map);

   /*local*/ extern virtual function void Xpredict_readX (uvm_reg_data_t  value,
                                                          uvm_path_e path,
                                                          uvm_reg_map  map);

   /*local*/ extern virtual function void Xpredict_writeX(uvm_reg_data_t  value,
                                                          uvm_path_e path,
                                                          uvm_reg_map  map);

   /*local*/ extern virtual function uvm_reg_data_t XupdX();
  

   extern function void pre_randomize();
   extern function void post_randomize();


   //------------------
   // Group: Attributes
   //------------------

   //
   // FUNCTION: set_attribute
   // Set an attribute.
   //
   // Set the specified attribute to the specified value for this field.
   // If the value is specified as "", the specified attribute is deleted.
   // A warning is issued if an existing attribute is modified.
   // 
   // Attribute names are case sensitive. 
   //
   extern virtual function void set_attribute(string name,
                                              string value);

   //
   // FUNCTION: get_attribute
   // Get an attribute value.
   //
   // Get the value of the specified attribute for this field.
   // If the attribute does not exists, "" is returned.
   // If ~inherited~ is specifed as TRUE, the value of the attribute
   // is inherited from its parent register
   // if it is not specified for this field.
   // If ~inherited~ is specified as FALSE, the value "" is returned
   // if it does not exists in the this field.
   // 
   // Attribute names are case sensitive.
   // 
   extern virtual function string get_attribute(string name,
                                                bit inherited = 1);

   //
   // FUNCTION: get_attributes
   // Get all attribute values.
   //
   // Get the name of all attribute for this field.
   // If ~inherited~ is specifed as TRUE, the value for all attributes
   // inherited from the parent register are included.
   // 
   extern virtual function void get_attributes(ref string names[string],
                                               input bit inherited = 1);

   //-----------------
   // Group: Callbacks
   //-----------------

   `uvm_register_cb(uvm_reg_field, uvm_reg_field_cbs)

   //--------------------------------------------------------------------------
   // TASK: pre_write
   // Called before field write.
   //
   // If the specified data value, access ~path~ or address ~map~ are modified,
   // the updated data value, access path or address map will be used
   // to perform the register operation.
   //
   // The field callback methods are invoked after the callback methods
   // on the containing register.
   // The registered callback methods are invoked after the invocation
   // of this method.
   //--------------------------------------------------------------------------
   virtual task pre_write  (ref uvm_reg_data_t  wdat,
                            ref uvm_path_e path,
                            ref uvm_reg_map     map);
   endtask

   //--------------------------------------------------------------------------
   // TASK: post_write
   // Called after field write
   //
   // If the specified ~status~ is modified,
   // the updated status will be
   // returned by the register operation.
   //
   // The field callback methods are invoked after the callback methods
   // on the containing register.
   // The registered callback methods are invoked before the invocation
   // of this method.
   //--------------------------------------------------------------------------
   virtual task post_write (uvm_reg_data_t        wdat,
                            uvm_path_e       path,
                            uvm_reg_map           map,
                            ref uvm_status_e status);
   endtask

   //--------------------------------------------------------------------------
   // TASK: pre_read
   // Called before field read.
   //
   // If the specified access ~path~ or address ~map~ are modified,
   // the updated access path or address map will be used to perform
   // the register operation.
   //
   // The field callback methods are invoked after the callback methods
   // on the containing register.
   // The registered callback methods are invoked after the invocation
   // of this method.
   //--------------------------------------------------------------------------
   virtual task pre_read   (ref uvm_path_e path,
                            ref uvm_reg_map     map);
   endtask

   //--------------------------------------------------------------------------
   // TASK: post_read
   // Called after field read.
   //
   // If the specified readback data or~status~ is modified,
   // the updated readback data or status will be
   // returned by the register operation.
   //
   // The field callback methods are invoked after the callback methods
   // on the containing register.
   // The registered callback methods are invoked before the invocation
   // of this method.
   //--------------------------------------------------------------------------
   virtual task post_read  (ref uvm_reg_data_t    rdat,
                            uvm_path_e       path,
                            uvm_reg_map           map,
                            ref uvm_status_e status);
   endtask


   extern virtual function void do_print (uvm_printer printer);
   extern virtual function string convert2string;
   extern virtual function uvm_object clone();
   extern virtual function void do_copy   (uvm_object rhs);
   extern virtual function bit  do_compare (uvm_object  rhs,
                                            uvm_comparer comparer);
   extern virtual function void do_pack (uvm_packer packer);
   extern virtual function void do_unpack (uvm_packer packer);

endclass: uvm_reg_field


//
// CLASS: uvm_reg_field_cbs
// Pre/post read/write callback facade class
//
class uvm_reg_field_cbs extends uvm_callback;
   string fname;
   int    lineno;

   function new(string name = "uvm_reg_field_cbs");
      super.new(name);
   endfunction
   

   //
   // Task: pre_write
   // Callback called before a write operation.
   //
   // The registered callback methods are invoked after the invocation
   // of the register pre-write callbacks and
   // of the <uvm_reg_field::pre_write()> method.
   //
   // The written value ~wdat, access ~path~ and address ~map~,
   // if modified, modifies the actual value, access path or address map
   // used in the register operation.
   //
   virtual task pre_write (uvm_reg_field       field,
                           ref uvm_reg_data_t  wdat,
                           ref uvm_path_e path,
                           ref uvm_reg_map     map);
   endtask


   //
   // TASK: post_write
   // Called after a write operation
   //
   // The registered callback methods are invoked after the invocation
   // of the register post-write callbacks and
   // before the invocation of the <uvm_reg_field::post_write()> method.
   //
   // The ~status~ of the operation,
   // if modified, modifies the actual returned status.
   //
   virtual task post_write(uvm_reg_field       field,
                           uvm_reg_data_t      wdat,
                           uvm_path_e     path,
                           uvm_reg_map         map,
                           ref uvm_status_e status);
   endtask


   //
   // TASK: pre_read
   // Called before a field read.
   //
   // The registered callback methods are invoked after the invocation
   // of the register pre-read callbacks and
   // after the invocation of the <uvm_reg_field::pre_read()> method.
   //
   // The access ~path~ and address ~map~,
   // if modified, modifies the actual access path or address map
   // used in the register operation.
   //
   virtual task pre_read  (uvm_reg_field       field,
                           ref uvm_path_e path,
                           ref uvm_reg_map     map);
   endtask


   //
   // TASK: post_read
   // Called after a field read.
   //
   // The registered callback methods are invoked after the invocation
   // of the register post-read callbacks and
   // before the invocation of the <uvm_reg_field::post_read()> method.
   //
   // The readback value ~rdat and the ~status~ of the operation,
   // if modified, modifies the actual returned readback value and status.
   //
   virtual task post_read (uvm_reg_field       field,
                           ref uvm_reg_data_t  rdat,
                           uvm_path_e     path,
                           uvm_reg_map         map,
                           ref uvm_status_e status);
   endtask

endclass: uvm_reg_field_cbs


//
// Type: uvm_reg_field_cb
// Convenience callback type declaration
//
// Use this declaration to register field callbacks rather than
// the more verbose parameterized class
//
typedef uvm_callbacks#(uvm_reg_field, uvm_reg_field_cbs) uvm_reg_field_cb;

//
// Type: uvm_reg_field_cb_iter
// Convenience callback iterator type declaration
//
// Use this declaration to iterate over registered field callbacks
// rather than the more verbose parameterized class
//
typedef uvm_callback_iter#(uvm_reg_field, uvm_reg_field_cbs) uvm_reg_field_cb_iter;



//
// IMPLEMENTATION
//

// new

function uvm_reg_field::new(string name = "uvm_reg_field");
   super.new(name);
endfunction: new


// configure

function void uvm_reg_field::configure(uvm_reg        parent,
                                       int unsigned   size,
                                       int unsigned   lsb_pos,
                                       string         access,
                                       bit            volatile,
                                       uvm_reg_data_t reset,
                                       bit            is_rand,
                                       bit            individually_accessible); 
   this.parent = parent;
   if (size == 0) begin
      `uvm_error("RegModel", $psprintf("Field \"%s\" cannot have 0 bits", this.get_full_name()));
      size = 1;
   end
   if (size > m_max_size) m_max_size = size;
   
   this.size                    = size;
   this.access                  = access.toupper();
   if (!m_policy_names.exists(this.access)) begin
      `uvm_error("RegModel", $psprintf("Access policy \"%s\" for field \"%s\" is not defined", this.access, get_full_name()));
      this.access = "RW";
   end
   this.m_volatile              = volatile;
   this.set_reset(reset);
   this.lsb                     = lsb_pos;
   this.individually_accessible = individually_accessible;
   this.cover_on                = UVM_NO_COVERAGE;
   if (!is_rand) this.value.rand_mode(0);
   this.parent.add_field(this);

   this.written = 0;
endfunction: configure


// get_parent

function uvm_reg uvm_reg_field::get_parent();
   return this.parent;
endfunction: get_parent


// get_full_name

function string uvm_reg_field::get_full_name();
   return {this.parent.get_full_name(), ".", this.get_name()};
endfunction: get_full_name


// get_register

function uvm_reg uvm_reg_field::get_register();
   return this.parent;
endfunction: get_register


// get_lsb_pos_in_register

function int unsigned uvm_reg_field::get_lsb_pos_in_register();
   return this.lsb;
endfunction: get_lsb_pos_in_register


// get_n_bits

function int unsigned uvm_reg_field::get_n_bits();
   return this.size;
endfunction: get_n_bits


// get_max_size

function int unsigned uvm_reg_field::get_max_size();
   return m_max_size;
endfunction: get_max_size


// is_known_access

function bit uvm_reg_field::is_known_access(uvm_reg_map map = null);
   string acc = this.get_access(map);
   case (acc)
    "RO", "RW", "RC", "RS", "WC", "WS",
      "W1C", "W1S", "W1T", "W0C", "W0S", "W0T",
      "WRC", "WRS", "W1SRC", "W1CRS", "W0SRC", "W0CRS", "WSRC", "WCRS",
      "WO", "WOC", "WOS", "W1", "WO1",
      "DC": return 1;
   endcase
   return 0;
endfunction


// get_access

function string uvm_reg_field::get_access(uvm_reg_map map = null);
   get_access = this.access;

   if (parent.get_n_maps() == 1 || map == uvm_reg_map::backdoor)
     return get_access;

   // Is the register restricted in this map?
   case (this.parent.get_rights(map))
     "RW":
       // No restrictions
       return get_access;

     "RO":
       case (get_access)
        "RW", "RO", "WC", "WS",
          "W1C", "W1S", "W1T", "W0C", "W0S", "W0T",
          "W1"
        : get_access = "RO";
        
        "RC", "WRC", "W1SRC", "W0SRC", "WSRC"
        : get_access = "RC";
        
        "RS", "WRS", "W1CRS", "W0CRS", "WCRS"
        : get_access = "RS";
        
         "WO", "WOC", "WOS", "WO1": begin
            `uvm_error("RegModel",
                       $psprintf("%s field \"%s\" restricted to RO in map \"%s\"",
                                 get_access, this.get_name(), map.get_full_name()));
         end

         // No change for the other modes
       endcase

     "WO":
       case (get_access)
         "RW",
         "WO": get_access = "WO";

         default: begin
            `uvm_error("RegModel",
                       $psprintf("%s field \"%s\" restricted to WO in map \"%s\"",
                                 get_access, this.get_name(), map.get_full_name()));
         end

         // No change for the other modes
       endcase

     default:
       `uvm_error("RegModel",
                  $psprintf("Shared register \"%s\" containing field \"%s\" is not shared in map \"%s\"",
                            this.parent.get_name(), this.get_name(), map.get_full_name()))
   endcase
endfunction: get_access


// set_access

function string uvm_reg_field::set_access(string mode);
   set_access = this.access;
   this.access = mode.toupper();
   if (!m_policy_names.exists(this.access)) begin
      `uvm_error("RegModel", $psprintf("Access policy \"%s\" is not a defined field access policy", this.access));
      this.access = set_access;
   end
endfunction: set_access


// define_access

function bit uvm_reg_field::define_access(string name);
   if (!m_predefined) m_predefined = m_predefine_policies();

   name = name.toupper();

   if (m_policy_names.exists(name)) return 0;

   m_policy_names[name] = 1;
   return 1;
endfunction


// m_predefined_policies

function bit uvm_reg_field::m_predefine_policies();
   if (m_predefined) return 1;

   m_predefined = 1;
   
   void'(define_access("RO"));
   void'(define_access("RW"));
   void'(define_access("RC"));
   void'(define_access("RS"));
   void'(define_access("WRC"));
   void'(define_access("WRS"));
   void'(define_access("WC"));
   void'(define_access("WS"));
   void'(define_access("WSRC"));
   void'(define_access("WCRS"));
   void'(define_access("W1C"));
   void'(define_access("W1S"));
   void'(define_access("W1T"));
   void'(define_access("W0C"));
   void'(define_access("W0S"));
   void'(define_access("W0T"));
   void'(define_access("W1SRC"));
   void'(define_access("W1CRS"));
   void'(define_access("W0SRC"));
   void'(define_access("W0CRS"));
   void'(define_access("WO"));
   void'(define_access("WOC"));
   void'(define_access("WOS"));
   void'(define_access("W1"));
   void'(define_access("WO1"));
   void'(define_access("DC"));
   return 1;
endfunction


// set_volatility

function void uvm_reg_field::set_volatility(bit volatile);
   m_volatile = volatile;
endfunction


// is_volatile

function bit uvm_reg_field::is_volatile();
   return m_volatile;
endfunction


//-----------
// ATTRIBUTES
//-----------

// set_attribute

function void uvm_reg_field::set_attribute(string name,
                                         string value);
   if (name == "") begin
      `uvm_error("RegModel", {"Cannot set anonymous attribute \"\" in field '",
                         get_full_name(),"'"})
      return;
   end

   if (this.attributes.exists(name)) begin
      if (value != "") begin
         `uvm_warning("RegModel", {"Redefining attribute '",name,"' in field '",
                         get_full_name(),"' to '",value,"'"})
         this.attributes[name] = value;
      end
      else begin
         this.attributes.delete(name);
      end
      return;
   end

   if (value == "") begin
      `uvm_warning("RegModel", {"Attempting to delete non-existent attribute '",
                          name, "' in field '", get_full_name(), "'"})
      return;
   end

   this.attributes[name] = value;
endfunction: set_attribute


// get_attribute

function string uvm_reg_field::get_attribute(string name,
                                             bit inherited = 1);
   if (inherited && parent != null)
      get_attribute = parent.get_attribute(name);

   if (get_attribute == "" && this.attributes.exists(name))
      return this.attributes[name];

   return "";
endfunction: get_attribute


// get_attributes

function void uvm_reg_field::get_attributes(ref string names[string],
                                          input bit inherited = 1);
   // attributes at higher levels supercede those at lower levels
   if (inherited && parent != null)
     this.parent.get_attributes(names,1);

   foreach (attributes[nm])
     if (!names.exists(nm))
       names[nm] = attributes[nm];

endfunction


// XpredictX

function uvm_reg_data_t uvm_reg_field::XpredictX (uvm_reg_data_t cur_val,
                                                  uvm_reg_data_t wr_val,
                                                  uvm_reg_map    map);
   uvm_reg_data_t mask = ('b1 << this.size)-1;
   
   case (this.get_access(map))
     "RO":    return cur_val;
     "RW":    return wr_val;
     "RC":    return cur_val;
     "RS":    return cur_val;
     "WC":    return '0;
     "WS":    return mask;
     "WRC":   return wr_val;
     "WRS":   return wr_val;
     "WSRC":  return mask;
     "WCRS":  return '0;
     "W1C":   return cur_val & (~wr_val);
     "W1S":   return cur_val | wr_val;
     "W1T":   return cur_val ^ wr_val;
     "W0C":   return cur_val & wr_val;
     "W0S":   return cur_val | (~wr_val & mask);
     "W0T":   return cur_val ^ (~wr_val & mask);
     "W1SRC": return cur_val | wr_val;
     "W1CRS": return cur_val & (~wr_val);
     "W0SRC": return cur_val | (~wr_val & mask);
     "W0CRS": return cur_val & wr_val;
     "WO":    return wr_val;
     "WOC":   return '0;
     "WOS":   return mask;
     "W1":    return (this.written) ? cur_val : wr_val;
     "WO1":   return (this.written) ? cur_val : wr_val;
     "DC":    return wr_val;
     default: return wr_val;
   endcase

   `uvm_fatal("RegModel", "uvm_reg_field::XpredictX(): Internal error");
   return 0;
endfunction: XpredictX


// Xpredict_readX

function void uvm_reg_field::Xpredict_readX (uvm_reg_data_t  value,
                                             uvm_path_e      path,
                                             uvm_reg_map     map);
   value &= ('b1 << this.size)-1;

   if (path == UVM_BFM) begin

      string acc = this.get_access(map);

      // If the value was obtained via a front-door access
      // then a RC field will have been cleared
      if (acc == "RC" ||
          acc == "WRC" ||
          acc == "W1SRC" ||
          acc == "W0SRC")
        value = 0;

      // If the value was obtained via a front-door access
      // then a RS field will have been set
      else if (acc == "RS" ||
               acc == "WRS" ||
               acc == "W1CRS" ||
               acc == "W0CRS")
        value = ('b1 << this.size)-1;

      // If the value of a WO field was obtained via a front-door access
      // it will always read back as 0 and the value of the field
      // cannot be inferred from it
      else if (acc == "WO" ||
               acc == "WOC" ||
               acc == "WOS" ||
               acc == "WO1") begin
        return;
      end
   end

   this.mirrored = value;
   this.desired  = value;
   this.value    = value;
endfunction: Xpredict_readX


// Xpredict_writeX 

function void uvm_reg_field::Xpredict_writeX (uvm_reg_data_t  value,
                                              uvm_path_e path,
                                              uvm_reg_map     map);
   if (value >> this.size) begin
      `uvm_warning("RegModel", $psprintf("Specified value (0x%h) greater than field \"%s\" size (%0d bits)",
                                       value, this.get_name(), this.size));
      value &= ('b1 << this.size)-1;
   end

   if (path == UVM_BFM) begin
      this.mirrored = this.XpredictX(this.mirrored, value, map);
   end
   else this.mirrored = value;

   this.desired = this.mirrored;
   this.value   = this.mirrored;

   this.written = 1;
endfunction: Xpredict_writeX


// XupdX

function uvm_reg_data_t  uvm_reg_field::XupdX();
   // Figure out which value must be written to get the desired value
   // given what we think is the current value in the hardware
   XupdX = 0;

   case (this.access)
      "RW":    XupdX = this.desired;
      "RO":    XupdX = this.desired;
      "WO":    XupdX = this.desired;
      "W1":    XupdX = this.desired;
      "RU":    XupdX = this.desired;
      "RC":    XupdX = this.desired;
      "W1C":   XupdX = ~this.desired;
      "A0":    XupdX = this.desired;
      "A1":    XupdX = this.desired;
      default: XupdX = this.desired;
   endcase
endfunction: XupdX


// predict

function bit uvm_reg_field::predict(uvm_reg_data_t  value,
                                    uvm_predict_e kind = UVM_PREDICT_DIRECT,
                                    uvm_path_e path = UVM_BFM,
                                    uvm_reg_map     map = null,
                                    string          fname = "",
                                    int             lineno = 0);
   this.fname = fname;
   this.lineno = lineno;
   if (this.parent.Xis_busyX && kind == UVM_PREDICT_DIRECT) begin
      `uvm_warning("RegModel", $psprintf("Trying to predict value of field \"%s\" while register \"%s\" is being accessed",
                                       this.get_name(),
                                       this.parent.get_full_name()));
      return 0;
   end

   if (kind == UVM_PREDICT_READ) begin
     Xpredict_readX(value,path,map);
     return 1;
   end

   if (kind == UVM_PREDICT_WRITE) begin
     Xpredict_writeX(value,path,map);
     return 1;
   end

   // update the mirror with value as-is
   value &= ('b1 << this.size)-1;
   this.mirrored = value;
   this.desired = value;
   this.value   = value;

   return 1;
endfunction: predict


// set

function void uvm_reg_field::set(uvm_reg_data_t  value,
                                 string          fname = "",
                                 int             lineno = 0);
   this.fname = fname;
   this.lineno = lineno;
   if (value >> this.size) begin
      `uvm_warning("RegModel", $psprintf("Specified value (0x%h) greater than field \"%s\" size (%0d bits)",
                                       value, this.get_name(), this.size));
      value &= ('b1 << this.size)-1;
   end

   case (this.access)
      "RW":    this.desired = value;
      "RO":    this.desired = this.desired;
      "WO":    this.desired = value;
      "W1":    this.desired = (this.written) ? this.desired : value;
      "RU":    this.desired = this.desired;
      "RC":    this.desired = this.desired;
      "W1C":   this.desired &= (~value);
      "A0":    this.desired |= value;
      "A1":    this.desired &= value;
      default: this.desired = value;
   endcase
   this.value = this.desired;
endfunction: set

 
// get

function uvm_reg_data_t  uvm_reg_field::get(string  fname = "",
                                            int     lineno = 0);
   this.fname = fname;
   this.lineno = lineno;
   get = this.desired;
endfunction: get


// reset

function void uvm_reg_field::reset(string kind = "HARD");
   if (!m_reset.exists(kind)) return;
   
   this.mirrored = m_reset[kind];
   this.desired  = this.mirrored;
   this.value    = this.mirrored;

   if (kind == "HARD") this.written  = 0;
endfunction: reset


// has_reset

function bit uvm_reg_field::has_reset(string kind = "HARD",
                                      bit    delete = 0);

   if (!m_reset.exists(kind)) return 0;

   if (delete) m_reset.delete(kind);

   return 1;
endfunction: has_reset


// get_reset

function uvm_reg_data_t
   uvm_reg_field::get_reset(string kind = "HARD");

   if (!m_reset.exists(kind)) return this.desired;

   return m_reset[kind];

endfunction: get_reset


// set_reset

function void uvm_reg_field::set_reset(uvm_reg_data_t value,
                                       string             kind = "HARD");
   m_reset[kind] = value;
endfunction: set_reset


// needs_update

function bit uvm_reg_field::needs_update();
   needs_update = (this.mirrored != this.desired);
endfunction: needs_update


typedef class uvm_reg_map_info;

// write

task uvm_reg_field::write(output uvm_status_e  status,
                          input  uvm_reg_data_t     value,
                          input  uvm_path_e    path = UVM_DEFAULT_PATH,
                          input  uvm_reg_map        map = null,
                          input  uvm_sequence_base  parent = null,
                          input  int                prior = -1,
                          input  uvm_object         extension = null,
                          input  string             fname = "",
                          input  int                lineno = 0);
   uvm_reg_data_t  tmp,msk,temp_data;
   uvm_reg_map local_map, system_map;
   uvm_reg_map_info map_info;

   bit [`UVM_REG_BYTENABLE_WIDTH-1:0] byte_en = '0;
   bit b_en[$];
   uvm_reg_field fields[$];
   bit bad_side_effect = 0;
   int fld_pos = 0;
   bit indv_acc = 0;
   int j = 0,bus_width, n_bits,n_access,n_access_extra,n_bytes_acc,temp_be;
   
   uvm_reg_block  blk = this.parent.get_block();
			
   if (path == UVM_DEFAULT_PATH)
     path = blk.get_default_path();

   local_map = this.parent.get_local_map(map,"read()");

   if (local_map != null)
      map_info = local_map.get_reg_map_info(this.parent);

   if (path != UVM_BACKDOOR && !this.parent.maps.exists(local_map) ) begin
     `uvm_error(get_type_name(), $psprintf("No transactor available to physically access map \"%s\".",
        map.get_full_name()));
     return;
   end
                        
   this.fname = fname;
   this.lineno = lineno;
   this.write_in_progress = 1'b1;

   this.parent.XatomicX(1);

   if (value >> this.size) begin
      `uvm_warning("RegModel", {"uvm_reg_field::write(): Value greater than field '",
                          get_full_name(),"'"})
      value &= value & ((1<<this.size)-1);
   end
			temp_data = value;
   tmp = 0;
   // What values are written for the other fields???
   this.parent.get_fields(fields);
   foreach (fields[i]) begin
      if (fields[i] == this) begin
         tmp |= value << this.lsb;
	 fld_pos = i;
         continue;
      end

      // It depends on what kind of bits they are made of...
      case (fields[i].get_access(local_map))
        // These...
        "RO",
        "RC",
        "RS",
        "W1C",
        "W1S",
        "W1T",
        "W1SRC",
        "W1CRC":
          // Use all 0's
          tmp |= 0;

        // These...
        "W0C",
        "W0S",
        "W0T",
        "W0SRC",
        "W0CRS":
          // Use all 1's
          tmp |= ((1<<fields[i].get_n_bits())-1) << fields[i].get_lsb_pos_in_register();

        // These might have side effects! Bad!
        "WC",
        "WS",
        "WCRS",
        "WSRC",
        "WOC",
        "WOS":
           bad_side_effect = 1;

        default:
          // Use their mirrored value
          tmp |= fields[i].get() << fields[i].get_lsb_pos_in_register();

      endcase
   end

`ifdef UVM_REG_NO_INDIVIDUAL_FIELD_ACCESS

   if (bad_side_effect) begin
      `uvm_warning("RegModel", $psprintf("Writing field \"%s\" will cause unintended side effects in adjoining Write-to-Clear or Write-to-Set fields in the same register", this.get_full_name()));
   end
   this.parent.XwriteX(status, tmp, path, map, parent, prior);

`else	

   system_map = local_map.get_root_map();
   bus_width = local_map.get_n_bytes();  //// get the width of the physical interface data bus in bytes
			
   //
   // Check if this field is the sole occupant of the
   // complete bus_data(width)
   //
   if (fields.size() == 1) begin
      indv_acc = 1;
   end
   else begin
      if (fld_pos == 0) begin
         if (fields[fld_pos+1].lsb%(bus_width*8) == 0)  indv_acc = 1;
         else if ((fields[fld_pos+1].lsb - fields[fld_pos].size) >= (fields[fld_pos+1].lsb%(bus_width*8))) indv_acc = 1;
         else indv_acc = 0;
      end 
      else if(fld_pos == (fields.size()-1)) begin
         if (fields[fld_pos].lsb%(bus_width*8) == 0)  indv_acc = 1;
         else if ((fields[fld_pos].lsb - (fields[fld_pos-1].lsb+fields[fld_pos-1].size)) >= (fields[fld_pos].lsb%(bus_width*8))) indv_acc = 1;
         else indv_acc = 0;
      end 
      else begin
         if (fields[fld_pos].lsb%(bus_width*8) == 0) begin
            if (fields[fld_pos+1].lsb%(bus_width*8) == 0) indv_acc = 1;
            else if ((fields[fld_pos+1].lsb - (fields[fld_pos].lsb+fields[fld_pos].size)) >= (fields[fld_pos+1].lsb%(bus_width*8))) indv_acc = 1;
            else indv_acc = 0;
         end 
         else begin
            if(((fields[fld_pos+1].lsb - (fields[fld_pos].lsb+fields[fld_pos].size))>= (fields[fld_pos+1].lsb%(bus_width*8)))  &&
               ((fields[fld_pos].lsb - (fields[fld_pos-1].lsb+fields[fld_pos-1].size))>=(fields[fld_pos].lsb%(bus_width*8))) ) indv_acc = 1;
            else indv_acc = 0;				
         end
      end
   end
			
   // BUILT-IN FRONTDOOR
   if (path == UVM_BFM) begin
      if(this.individually_accessible) begin
         uvm_reg_adapter    adapter;
         uvm_sequencer_base sequencer;
         bit is_passthru;
         uvm_reg_passthru_adapter passthru_adapter;

         if (local_map == null)
           return;

         system_map = local_map.get_root_map();

         adapter = system_map.get_adapter();
         sequencer = system_map.get_sequencer();
         if ($cast(passthru_adapter,adapter))
            is_passthru = 1;

   	 if(adapter.supports_byte_enable || (indv_acc)) begin

	    uvm_reg_field_cb_iter cbs = new(this);
	    value = temp_data;

            // PRE-WRITE CBS
            this.pre_write(value, path, map);
            for (uvm_reg_field_cbs cb = cbs.first(); cb != null;
                 cb = cbs.next()) begin
               cb.fname = this.fname;
               cb.lineno = this.lineno;
               cb.pre_write(this, value, path, map);
            end
	    this.parent.Xis_busyX = 1;
            
	    n_access_extra = this.lsb%(bus_width*8);		
	    n_access = n_access_extra + this.size;
	    value = (value) << (n_access_extra);
	    /* calculate byte_enables */
	    temp_be = n_access_extra;
            while(temp_be >= 8) begin
	       b_en.push_back(0);
               temp_be = temp_be - 8;
	    end			
	    temp_be = temp_be + this.size;
     	    while(temp_be > 0) begin
	       b_en.push_back(1);
               temp_be = temp_be - 8;
	    end
	    /* calculate byte_enables */
            
	    if(n_access%8 != 0) n_access = n_access + (8 - (n_access%8)); 
            n_bytes_acc = n_access/8;
            
            j = 0;
	    n_bits = this.size;
            foreach(map_info.addr[i]) begin
               uvm_sequence_item bus_req = new("bus_wr");
               uvm_reg_bus_item rw_access;
	       uvm_reg_data_t  data;
	       bit tt;
	       data = value >> (j*8);
	       
	       for(int z=0;z<bus_width;z++) begin
		  tt = b_en.pop_front();	
		  byte_en[z] = tt;
	       end	
               

               data = value >> (j*8);

               status = UVM_NOT_OK;
                           
               `uvm_info(get_type_name(), $psprintf("Writing 'h%0h at 'h%0h via map \"%s\"...",
                                                    data, map_info.addr[i], map.get_full_name()), UVM_HIGH);
                        
               rw_access = uvm_reg_bus_item::type_id::create("rw_access",,{sequencer.get_full_name(),".",parent.get_full_name()});
               rw_access.element = this;
               rw_access.element_kind = UVM_REG;
               rw_access.kind = UVM_WRITE;
               rw_access.value = value;
               rw_access.path = path;
               rw_access.map = local_map;
               rw_access.extension = extension;
               rw_access.fname = fname;
               rw_access.lineno = lineno;

               rw_access.addr = map_info.addr[i];
               rw_access.data = data;
               rw_access.n_bits = (n_bits > bus_width*8) ? bus_width*8 : n_bits;
               rw_access.byte_en = '1;

               bus_req.m_start_item(sequencer,parent,prior);
               if (!is_passthru)
                 parent.mid_do(rw_access);
               bus_req = adapter.reg2bus(rw_access);
               bus_req.m_finish_item(sequencer,parent);
               bus_req.end_event.wait_on();
               if (adapter.provides_responses) begin
                 uvm_sequence_item bus_rsp;
                 uvm_access_e op;
                 parent.get_base_response(bus_rsp);
                 adapter.bus2reg(bus_rsp,rw_access);
               end
               else begin
                 adapter.bus2reg(bus_req,rw_access);
               end
               status = rw_access.status;
               if (!is_passthru)
                 parent.post_do(rw_access);

               `uvm_info(get_type_name(), $psprintf("Wrote 'h%0h at 'h%0h via map \"%s\": %s...",
                                                    data, map_info.addr[i], map.get_full_name(), status.name()), UVM_HIGH);

               if (status != UVM_IS_OK && status != UVM_HAS_X) return;
               j += bus_width;
               n_bits -= bus_width * 8;
            end
            /*if (this.cover_on) begin
             this.sample(value, 0, di);
             this.parent.XsampleX(this.offset_in_block[di], di);
         end*/
            
            this.parent.Xis_busyX = 0;
	    value = (value >> (n_access_extra)) & ((1<<this.size))-1;

            if (system_map.get_auto_predict() == UVM_PREDICT_DIRECT)
	      this.Xpredict_writeX(value, path, map);
            
            // POST-WRITE CBS
            this.post_write(value, path, map, status);
            for (uvm_reg_field_cbs cb = cbs.first(); cb != null;
                 cb = cbs.next()) begin
               cb.fname = this.fname;
               cb.lineno = this.lineno;
               cb.post_write(this, value, path, map, status);
            end
   	 end else begin
   	    if(!adapter.supports_byte_enable) begin
               `uvm_warning("RegModel", $psprintf("Protocol does not support byte enabling to write field \"%s\". Writing complete register instead.", this.get_name()));
   	    end		
   	    if(!indv_acc) begin
               `uvm_warning("RegModel", $psprintf("Field \"%s\" is not individually accessible. Writing complete register instead.", this.get_name()));
   	    end		
            if (bad_side_effect) begin
               `uvm_warning("RegModel", $psprintf("Writing field \"%s\" will cause unintended side effects in adjoining Write-to-Clear or Write-to-Set fields in the same register", this.get_full_name()));
            end
            this.parent.XwriteX(status, tmp, path, map, parent, prior);
   	 end	
      end else begin
         `uvm_warning("RegModel", $psprintf("Individual field access not available for field \"%s\". Writing complete register instead.", this.get_name()));
         if (bad_side_effect) begin
            `uvm_warning("RegModel", $psprintf("Writing field \"%s\" will cause unintended side effects in adjoining Write-to-Clear or Write-to-Set fields in the same register", this.get_full_name()));
         end
         this.parent.XwriteX(status, tmp, path, map, parent, prior);
      end	
   end

   // Individual field access not available for BACKDOOR access		
   if(path == UVM_BACKDOOR) begin
      `uvm_warning("RegModel", $psprintf("Individual field access not available with BACKDOOR access for field \"%s\". Writing complete register instead.", this.get_name()));
      if (bad_side_effect) begin
         `uvm_warning("RegModel", $psprintf("Writing field \"%s\" will cause unintended side effects in adjoining Write-to-Clear or Write-to-Set fields in the same register", this.get_full_name()));
      end
      this.parent.XwriteX(status, tmp, path, map, parent, prior);
   end
`endif
   this.parent.XatomicX(0);
   this.write_in_progress = 1'b0;
endtask: write


// read

task uvm_reg_field::read(output uvm_status_e  status,
                         output uvm_reg_data_t     value,
                         input  uvm_path_e    path = UVM_DEFAULT_PATH,
                         input  uvm_reg_map        map = null,
                         input  uvm_sequence_base  parent = null,
                         input  int                prior = -1,
                         input  uvm_object         extension = null,
                         input  string             fname = "",
                         input  int                lineno = 0);
   uvm_reg_data_t  reg_value;
   uvm_reg_map local_map, system_map;
   uvm_reg_map_info map_info;
   bit [`UVM_REG_BYTENABLE_WIDTH-1:0] byte_en = '0;
   bit b_en[$];
   int j = 0,bus_width, n_bits,n_access,n_access_extra,n_bytes_acc,temp_be;
   uvm_reg_field fields[$];
   bit bad_side_effect = 0;
   int fld_pos = 0;
   int rh_shift = 0;
   bit indv_acc = 0;
   
   uvm_reg_block  blk = this.parent.get_block();
			
   this.fname = fname;
   this.lineno = lineno;
   this.read_in_progress = 1'b1;

   if (path == UVM_DEFAULT_PATH) path = blk.get_default_path();

   local_map = this.parent.get_local_map(map,"read()");

   if (local_map != null)
      map_info = local_map.get_reg_map_info(this.parent);

   if (path != UVM_BACKDOOR && !this.parent.maps.exists(local_map)) begin
     `uvm_error(get_type_name(), $psprintf("No transactor available to physically access map \"%s\".",
        map.get_full_name()));
     return;
   end
                        

`ifdef UVM_REG_NO_INDIVIDUAL_FIELD_ACCESS
   bad_side_effect = 1;
   this.parent.read(status, reg_value, path, map, parent, prior, extension, fname, lineno);
			value = (reg_value >> this.lsb) & ((1<<this.size))-1;
`else
   system_map = local_map.get_root_map();
   bus_width = local_map.get_n_bytes();  //// get the width of the physical interface data bus in bytes
   
   /* START to check if this field is the sole occupant of the complete bus_data(width) */
   this.parent.get_fields(fields);
   foreach (fields[i]) begin
      if (fields[i] == this) begin
	 fld_pos = i;
      end
			end			
   if(fields.size() == 1)	begin
      indv_acc = 1;
   end else begin
      if(fld_pos == 0) begin
         if (fields[fld_pos+1].lsb%(bus_width*8) == 0)  indv_acc = 1;
         else if ((fields[fld_pos+1].lsb - fields[fld_pos].size) >= (fields[fld_pos+1].lsb%(bus_width*8))) indv_acc = 1;
         else indv_acc = 0;
      end 
      else if(fld_pos == (fields.size()-1)) begin
         if (fields[fld_pos].lsb%(bus_width*8) == 0)  indv_acc = 1;
         else if ((fields[fld_pos].lsb - (fields[fld_pos-1].lsb+fields[fld_pos-1].size)) >= (fields[fld_pos].lsb%(bus_width*8))) indv_acc = 1;
         else indv_acc = 0;
      end 
      else begin
         if (fields[fld_pos].lsb%(bus_width*8) == 0) begin
            if (fields[fld_pos+1].lsb%(bus_width*8) == 0) indv_acc = 1;
            else if ((fields[fld_pos+1].lsb - (fields[fld_pos].lsb+fields[fld_pos].size)) >= (fields[fld_pos+1].lsb%(bus_width*8))) indv_acc = 1;
            else indv_acc = 0;
         end 
         else begin
            if(((fields[fld_pos+1].lsb - (fields[fld_pos].lsb+fields[fld_pos].size))>= (fields[fld_pos+1].lsb%(bus_width*8)))  &&
               ((fields[fld_pos].lsb - (fields[fld_pos-1].lsb+fields[fld_pos-1].size))>=(fields[fld_pos].lsb%(bus_width*8))) ) indv_acc = 1;
            else indv_acc = 0;				
         end
      end
   end
   /* END to check if this field is the sole occupant of the complete bus_data(width) */

   if (path == UVM_BFM) begin

      if (this.individually_accessible) begin

         uvm_reg_adapter    adapter;
         uvm_sequencer_base sequencer;
         bit is_passthru;
         uvm_reg_passthru_adapter passthru_adapter;

         if (local_map == null)
           return;

         system_map = local_map.get_root_map();

         adapter = system_map.get_adapter();
         sequencer = system_map.get_sequencer();
         if ($cast(passthru_adapter,adapter))
            is_passthru = 1;

   	 if(adapter.supports_byte_enable || (indv_acc)) begin
            uvm_reg_field_cb_iter cbs = new(this);
            this.parent.XatomicX(1);
            this.parent.Xis_busyX = 1;
            this.pre_read(path, map);
            for (uvm_reg_field_cbs cb = cbs.first(); cb != null;
                 cb = cbs.next()) begin
               cb.fname = this.fname;
               cb.lineno = this.lineno;
               cb.pre_read(this, path, map);
            end
	    
	    n_access_extra = this.lsb%(bus_width*8);		
	    n_access = n_access_extra + this.size;
	    
	    /* calculate byte_enables */
	    temp_be = n_access_extra;
            while(temp_be >= 8) begin
	       b_en.push_back(0);
               temp_be = temp_be - 8;
	    end			
	    temp_be = temp_be + this.size;
     	    while(temp_be > 0) begin
	       b_en.push_back(1);
               temp_be = temp_be - 8;
	    end
	    /* calculate byte_enables */
	    
            if(n_access%8 != 0) n_access = n_access + (8 - (n_access%8)); 
            n_bytes_acc = n_access/8;

            n_bits = this.size;

            foreach(map_info.addr[i]) begin
               uvm_sequence_item bus_req = new("bus_rd");
               uvm_reg_bus_item rw_access;
	       uvm_reg_data_t  data;	
	       bit tt;
	       
 	       for(int z=0;z<bus_width;z++) begin
	  	  tt = b_en.pop_front();	
		  byte_en[z] = tt;
	       end	

               `uvm_info(get_type_name(), $psprintf("Reading 'h%0h at 'h%0h via map \"%s\"...",
                                                    data, map_info.addr[i], map.get_full_name()), UVM_HIGH);
                        
                rw_access = uvm_reg_bus_item::type_id::create("rw_access",,{sequencer.get_full_name(),".",parent.get_full_name()});
                rw_access.element = this;
                rw_access.element_kind = UVM_REG;
                rw_access.kind = UVM_READ;
                rw_access.value = value;
                rw_access.path = path;
                rw_access.map = local_map;
                rw_access.extension = extension;
                rw_access.fname = fname;
                rw_access.lineno = lineno;


                rw_access.addr = map_info.addr[i];
                rw_access.data = data;
                rw_access.n_bits = (n_bits > bus_width*8) ? bus_width*8 : n_bits;
                rw_access.byte_en = '1;
                            
                bus_req.m_start_item(sequencer,parent,prior);
                if (!is_passthru)
                  parent.mid_do(rw_access);
                bus_req = adapter.reg2bus(rw_access);
                bus_req.m_finish_item(sequencer,parent);
                bus_req.end_event.wait_on();
                if (adapter.provides_responses) begin
                  uvm_sequence_item bus_rsp;
                  uvm_access_e op;
                  parent.get_base_response(bus_rsp);
                  adapter.bus2reg(bus_rsp,rw_access);
                end
                else begin
                  adapter.bus2reg(bus_req,rw_access);
                end
                data = rw_access.data & ((1<<bus_width*8)-1);
                if (rw_access.status == UVM_IS_OK && (^data) === 1'bx)
                  rw_access.status = UVM_HAS_X;
                status = rw_access.status;


                `uvm_info(get_type_name(), $psprintf("Read 'h%0h at 'h%0h via map \"%s\": %s...",
                                                    data, map_info.addr[i], map.get_full_name(), status.name()), UVM_HIGH);


               if (status != UVM_IS_OK && status != UVM_HAS_X) return;

   	       reg_value |= data & j*8;
               rw_access.value = reg_value;
               if (!is_passthru)
                 parent.post_do(rw_access);
               j += bus_width;
               n_bits -= bus_width * 8;
            end
            this.parent.Xis_busyX = 0;
	    /*if (this.cover_on) begin
             parent.sample(value, 1, map);
             parent.parent.XsampleX(parent.offset_in_block[map], map);
         end*/
	    value = (reg_value >> (n_access_extra)) & ((1<<this.size))-1;

            if (system_map.get_auto_predict() == UVM_PREDICT_DIRECT)
	      this.Xpredict_readX(value, path, map);

            this.post_read(value, path, map, status);
            for (uvm_reg_field_cbs cb = cbs.first(); cb != null;
                 cb = cbs.next()) begin
               cb.fname = this.fname;
               cb.lineno = this.lineno;
               cb.post_read(this, value, path, map, status);
            end

            this.parent.XatomicX(0);
	    this.fname = "";
	    this.lineno = 0;
	    
   	 end else begin
   	    if(!adapter.supports_byte_enable) begin
               `uvm_warning("RegModel", $psprintf("Protocol doesnot support byte enabling ....\n Reading complete register instead."));
   	    end		
   	    if((this.size%8)!=0) begin
               `uvm_warning("RegModel", $psprintf("Field \"%s\" is not byte aligned. Individual field access will not be available ...\nReading complete register instead.", this.get_name()));
   	    end		
            bad_side_effect = 1;
            this.parent.read(status, reg_value, path, map, parent, prior, extension, fname, lineno);
            value = (reg_value >> this.lsb) & ((1<<this.size))-1;
   	 end	
      end else begin
         `uvm_warning("RegModel", $psprintf("Individual field access not available for field \"%s\". Reading complete register instead.", this.get_name()));
         bad_side_effect = 1;
         this.parent.read(status, reg_value, path, map, parent, prior, extension, fname, lineno);
         value = (reg_value >> this.lsb) & ((1<<this.size))-1;
      end	
   end
   /// Individual field access not available for BACKDOOR access		
   if(path == UVM_BACKDOOR) begin
      `uvm_warning("RegModel", $psprintf("Individual field access not available with BACKDOOR access for field \"%s\". Reading complete register instead.", this.get_name()));
      bad_side_effect = 1;
      this.parent.read(status, reg_value, path, map, parent, prior, extension, fname, lineno);
      value = (reg_value >> this.lsb) & ((1<<this.size))-1;
   end
`endif
   this.read_in_progress = 1'b0;

   if (bad_side_effect) begin
      foreach (fields[i]) begin
         string mode;
         if (fields[i] == this) continue;
         mode = fields[i].get_access();
         if (mode == "RC" ||
             mode == "RS" ||
             mode == "WRC" ||
             mode == "WRS" ||
             mode == "WSRC" ||
             mode == "WCRS" ||
             mode == "W1SRC" ||
             mode == "W1CRS" ||
             mode == "W0SRC" ||
             mode == "W0CRS") begin
            `uvm_warning("RegModel", $psprintf("Reading field \"%s\" will cause unintended side effects in adjoining Read-to-Clear or Read-to-Set fields in the same register", this.get_full_name()));
         end
      end
   end

endtask: read
               

// poke

task uvm_reg_field::poke(output uvm_status_e status,
                         input  uvm_reg_data_t    value,
                         input  string            kind = "",
                         input  uvm_sequence_base parent = null,
                         input  uvm_object        extension = null,
                         input  string            fname = "",
                         input  int               lineno = 0);
   uvm_reg_data_t  tmp;

   this.fname = fname;
   this.lineno = lineno;

   if (value >> this.size) begin
      `uvm_warning("RegModel", $psprintf("uvm_reg_field::poke(): Value greater than field \"%s\" size", this.get_name()));
      value &= value & ((1<<this.size)-1);
   end


   this.parent.XatomicX(1);
   this.parent.Xis_locked_by_fieldX = 1'b1;

   tmp = 0;
   // What is the current values of the other fields???
   this.parent.peek(status, tmp, kind, parent, extension, fname, lineno);
   if (status != UVM_IS_OK && status != UVM_HAS_X) begin
      `uvm_error("RegModel", $psprintf("uvm_reg_field::poke(): Peeking register \"%s\" returned status %s", this.parent.get_full_name(), status.name()));
      this.parent.XatomicX(0);
      this.parent.Xis_locked_by_fieldX = 1'b0;
      return;
   end

   // Force the value for this field then poke the resulting value
   tmp &= ~(((1<<this.size)-1) << this.lsb);
   tmp |= value << this.lsb;
   this.parent.poke(status, tmp, kind, parent, extension, fname, lineno);

   this.parent.XatomicX(0);
   this.parent.Xis_locked_by_fieldX = 1'b0;
endtask: poke


// peek

task uvm_reg_field::peek(output uvm_status_e status,
                         output uvm_reg_data_t    value,
                         input  string            kind = "",
                         input  uvm_sequence_base parent = null,
                         input  uvm_object        extension = null,
                         input  string            fname = "",
                         input  int               lineno = 0);
   uvm_reg_data_t  reg_value;

   this.fname = fname;
   this.lineno = lineno;

   this.parent.peek(status, reg_value, kind, parent, extension, fname, lineno);
   value = (reg_value >> lsb) & ((1<<size))-1;

endtask: peek
               

// mirror

task uvm_reg_field::mirror(output uvm_status_e status,
                           input  uvm_check_e  check = UVM_NO_CHECK,
                           input  uvm_path_e   path = UVM_DEFAULT_PATH,
                           input  uvm_reg_map       map = null,
                           input  uvm_sequence_base parent = null,
                           input  int               prior = -1,
                           input  uvm_object        extension = null,
                           input  string            fname = "",
                           input  int               lineno = 0);
   this.fname = fname;
   this.lineno = lineno;
   this.parent.mirror(status, check, path, map, parent, prior, extension,
                      fname, lineno);
endtask: mirror


// pre_randomize

function void uvm_reg_field::pre_randomize();
   // Update the only publicly known property with the current
   // desired value so it can be used as a state variable should
   // the rand_mode of the field be turned off.
   this.value = this.desired;
endfunction: pre_randomize


// post_randomize

function void uvm_reg_field::post_randomize();
   this.desired = this.value;
endfunction: post_randomize


// do_print

function void uvm_reg_field::do_print (uvm_printer printer);
  super.do_print(printer);
  printer.print_generic("initiator", parent.get_type_name(), -1, convert2string());
endfunction


// convert2string

function string uvm_reg_field::convert2string();
   string fmt;
   string res_str = "";
   string t_str = "";
   bit with_debug_info = 0;
   string prefix = "";

   $sformat(fmt, "%0d'h%%%0dh", this.get_n_bits(),
            (this.get_n_bits()-1)/4 + 1);
   $sformat(convert2string, {"%s%s[%0d-%0d] = ",fmt,"%s"}, prefix,
            this.get_name(),
            this.get_lsb_pos_in_register() + this.get_n_bits() - 1,
            this.get_lsb_pos_in_register(), this.desired,
            (this.desired != this.mirrored) ? $psprintf({" (Mirror: ",fmt,")"}, this.mirrored) : "");

   if (read_in_progress == 1'b1) begin
      if (fname != "" && lineno != 0)
         $sformat(res_str, " from %s:%0d",fname, lineno);
      convert2string = {convert2string, "\n", "currently being read", res_str}; 
   end
   if (write_in_progress == 1'b1) begin
      if (fname != "" && lineno != 0)
         $sformat(res_str, " from %s:%0d",fname, lineno);
      convert2string = {convert2string, "\n", res_str, "currently being written"}; 
   end
   if (this.attributes.num() > 0) begin
      string name;
      void'(this.attributes.first(name));
      convert2string = {convert2string, "\n", prefix, "Attributes:"};
      do begin
         $sformat(convert2string, " %s=\"%s\"", name, this.attributes[name]);
      end while (this.attributes.next(name));
   end
endfunction: convert2string


// clone

function uvm_object uvm_reg_field::clone();
  `uvm_fatal("RegModel","RegModel field cannot be cloned")
  return null;
endfunction

// do_copy

function void uvm_reg_field::do_copy(uvm_object rhs);
  `uvm_warning("RegModel","RegModel field copy not yet implemented")
  // just a this.set(rhs.get()) ?
endfunction


// do_compare

function bit uvm_reg_field::do_compare (uvm_object  rhs,
                                        uvm_comparer comparer);
  `uvm_warning("RegModel","RegModel field compare not yet implemented")
  // just a return (this.get() == rhs.get()) ?
  return 0;
endfunction


// do_pack

function void uvm_reg_field::do_pack (uvm_packer packer);
  `uvm_warning("RegModel","RegModel field cannot be packed")
endfunction


// do_unpack

function void uvm_reg_field::do_unpack (uvm_packer packer);
  `uvm_warning("RegModel","RegModel field cannot be unpacked")
endfunction

