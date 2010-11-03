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

//------------------------------------------------------------------------------
// Title: User-Defined Backdoor Access
//
// The following classes are defined herein:
//
// <uvm_reg_backdoor> : base for user-defined backdoor register and memory access
//
// <uvm_reg_cbs> : base for user-defined callbacks for registers, memories, fields,
// and backdoor accesses.
//
//------------------------------------------------------------------------------


typedef class uvm_reg_cbs;


//------------------------------------------------------------------------------
//
// Class: uvm_reg_backdoor
//
// Base class for user-defined back-door register and memory access.
//
// This class can be extended by users to provide user-specific back-door access
// to registers and memories that are not implemented in pure SystemVerilog
// or that are not accessible using the default DPI backdoor mechanism.
//------------------------------------------------------------------------------

class uvm_reg_backdoor extends uvm_object;

   // Function: new
   //
   // Create an instance of this class
   //
   // Create an instance of the user-defined backdoor class
   // for the specified register or memory
   //
   function new(string name = "");
      super.new(name);
   endfunction: new

   
   // Task: do_pre_read
   //
   // Execute the pre-read callbacks
   //
   // This method ~must~ be called as the first statement in
   // a user extension of the <read()> method.
   //
   protected task do_pre_read(uvm_reg_item rw);
      pre_read(rw);
      `uvm_do_obj_callbacks(uvm_reg_backdoor, uvm_reg_cbs, this,
                            pre_read(rw))
   endtask


   // Task: do_post_read
   //
   // Execute the post-read callbacks
   //
   // This method ~must~ be called as the last statement in
   // a user extension of the <read()> method.
   //
   protected task do_post_read(uvm_reg_item rw);
      uvm_callback_iter#(uvm_reg_backdoor, uvm_reg_cbs) iter = new(this);
      for(uvm_reg_cbs cb = iter.last(); cb != null; cb=iter.prev())
         cb.decode(rw.value);
      `uvm_do_obj_callbacks(uvm_reg_backdoor,uvm_reg_cbs,this,post_read(rw))
      post_read(rw);
   endtask


   // Task: do_pre_write
   //
   // Execute the pre-write callbacks
   //
   // This method ~must~ be called as the first statement in
   // a user extension of the <write()> method.
   //
   protected task do_pre_write(uvm_reg_item rw);
      uvm_callback_iter#(uvm_reg_backdoor, uvm_reg_cbs) iter = new(this);
      pre_write(rw);
      `uvm_do_obj_callbacks(uvm_reg_backdoor,uvm_reg_cbs,this,pre_write(rw))
      for(uvm_reg_cbs cb = iter.first(); cb != null; cb = iter.next())
         cb.encode(rw.value);
   endtask


   // Task: do_post_write
   //
   // Execute the post-write callbacks
   //
   // This method ~must~ be called as the last statement in
   // a user extension of the <write()> method.
   //
   protected task do_post_write(uvm_reg_item rw);
      `uvm_do_obj_callbacks(uvm_reg_backdoor,uvm_reg_cbs,this,post_write(rw))
      post_write(rw);
   endtask


   // Task: write
   //
   // User-defined backdoor write operation.
   //
   // Call <do_pre_write()>.
   // Deposit the specified value in the specified register HDL implementation.
   // Call <do_post_write()>.
   // Returns an indication of the success of the operation.
   //
   extern virtual task write(uvm_reg_item rw);


   // Task: read
   //
   // User-defined backdoor read operation.
   //
   // Overload this method only if the backdoor requires the use of task.
   //
   // Call <do_pre_read()>.
   // Peek the current value of the specified HDL implementation.
   // Call <do_post_read()>.
   // Returns the current value and an indication of the success of
   // the operation.
   //
   // By default, calls <read_func()>.
   //
   extern virtual task read(uvm_reg_item rw);

   
   // Function: read_func
   //
   // User-defined backdoor read operation.
   //
   // Peek the current value in the HDL implementation.
   // Returns the current value and an indication of the success of
   // the operation.
   //
   extern virtual function void read_func(uvm_reg_item rw);


   // Function: is_auto_updated
   //
   // Indicates if wait_for_change() method is implemented
   //
   // Implement to return TRUE if and only if
   // <wait_for_change()> is implemented to watch for changes
   // in the HDL implementation of the specified field
   //
   extern virtual function bit is_auto_updated(uvm_reg_field field);


   // Task: wait_for_change
   //
   // Wait for a change in the value of the register or memory
   // element in the DUT.
   //
   // When this method returns, the mirror value for the register
   // corresponding to this instance of the backdoor class will be updated
   // via a backdoor read operation.
   //
   extern virtual local task wait_for_change(uvm_object element);

  
   /*local*/ extern function void start_update_thread(uvm_object element);
   /*local*/ extern function void kill_update_thread(uvm_object element);
   /*local*/ extern function bit has_update_threads();


   // Task: pre_read
   //
   // Called before user-defined backdoor register read.
   //
   // The registered callback methods are invoked after the invocation
   // of this method.
   //
   virtual task pre_read(uvm_reg_item rw); endtask


   // Task: post_read
   //
   // Called after user-defined backdoor register read.
   //
   // The registered callback methods are invoked before the invocation
   // of this method.
   //
   virtual task post_read(uvm_reg_item rw); endtask


   // Task: pre_write
   //
   // Called before user-defined backdoor register write.
   //
   // The registered callback methods are invoked after the invocation
   // of this method.
   //
   // The written value, if modified, modifies the actual value that
   // will be written.
   //
   virtual task pre_write(uvm_reg_item rw); endtask


   // Task: post_write
   //
   // Called after user-defined backdoor register write.
   //
   // The registered callback methods are invoked before the invocation
   // of this method.
   //
   virtual task post_write(uvm_reg_item rw); endtask


   string fname;
   int lineno;

   local uvm_reg_cbs backdoor_cbs[$];

   local process m_update_thread[uvm_object];

   `uvm_object_utils(uvm_reg_backdoor)
   `uvm_register_cb(uvm_reg_backdoor, uvm_reg_cbs)


endclass: uvm_reg_backdoor


//------------------------------------------------------------------------------
// Class: uvm_reg_frontdoor
//
// Fa�ade class for register and memory frontdoor access.
//------------------------------------------------------------------------------
//
// User-defined frontdoor access sequence
//
// Base class for user-defined access to register and memory reads and writes
// through a physical interface.
//
// By default, different registers and memories are mapped to different
// addresses in the address space and are accessed via those exclusively
// through physical addresses.
//
// The frontdoor allows access using a non-linear and/or non-mapped mechanism.
// Users can extend this class to provide the physical access to these registers.
//
virtual class uvm_reg_frontdoor extends uvm_reg_sequence #(uvm_sequence #(uvm_sequence_item));

   // Variable: rw_info
   //
   // Holds information about the register being read or written
   //
   uvm_reg_item rw_info;

   // Variable: sequencer
   //
   // Sequencer executing the operation
   //
   uvm_sequencer_base sequencer;

   // Function: new
   //
   // Constructor, new object givne optional ~name~.
   //
   function new(string name="");
      super.new(name);
   endfunction

   string fname;
   int lineno;

endclass: uvm_reg_frontdoor


//------------------------------------------------------------------------------
// Class: uvm_reg_cbs
//
// Fa�ade class for register and memory backdoor access callback methods. 
//------------------------------------------------------------------------------
virtual class uvm_reg_cbs extends uvm_callback;


   function new(string name = "uvm_reg_cbs");
      super.new(name);
   endfunction


   // Task: pre_write
   //
   // Called before a write operation.
   //
   // All registered ~pre_write~ callback methods are invoked after the
   // invocation of the ~pre_write~ method of associated object (<uvm_reg>,
   // <uvm_reg_field>, <uvm_mem>, or <uvm_reg_backdoor>). If the element being
   // written is a <uvm_reg>, all ~pre_write~ callback methods are invoked
   // before the contained <uvm_reg_fields>. 
   //
   // Backdoor - <uvm_reg_backdoor::pre_write>,
   //            <uvm_reg_cbs>::pre_write> cbs for backdoor
   //
   // Register - <uvm_reg::pre_write>,
   //            <uvm_reg_cbs>::pre_write> cbs for reg,
   //            foreach field {
   //              <uvm_reg_field::pre_write>,
   //              <uvm_reg_cbs::pre_write> cbs for field
   //            }
   //
   // RegField - <uvm_reg_field::pre_write>,
   //            <uvm_reg_cbs::pre_write> cbs for field
   //
   // Memory   - <uvm_mem::pre_write>,
   //            <uvm_reg_cbs>::pre_write> cbs for mem
   //
   // The ~rw~ argument holds information about the operation.
   //
   // - Modifying the ~value~ modifies the actual value written.
   //
   // - For memories, modifying the ~offset~ modifies the offset
   //   used in the operation.
   //
   // - For non-backdoor operations, modifying the access ~path~ or
   //   address ~map~ modifies the actual path or map used in the
   //   operation.
   //
   // See <uvm_reg_item> for details on ~rw~ information.
   //
   virtual task pre_write(uvm_reg_item rw); endtask


   // Task: post_write
   //
   // Called after user-defined backdoor register write.
   //
   // All registered ~post_write~ callback methods are invoked before the
   // invocation of the ~post_write~ method of the associated object (<uvm_reg>,
   // <uvm_reg_field>, <uvm_mem>, or <uvm_reg_backdoor>). If the element being
   // written is a <uvm_reg>, all ~post_write~ callback methods are invoked
   // before the contained <uvm_reg_fields>. 
   //
   // Summary of callback order:
   //
   // Backdoor - <uvm_reg_cbs>::post_write> cbs for backdoor,
   //            <uvm_reg_backdoor::post_write>
   //
   // Register - <uvm_reg_cbs>::post_write> cbs for reg,
   //            <uvm_reg::post_write>,
   //            foreach field {
   //              <uvm_reg_cbs::post_write> cbs for field,
   //              <uvm_reg_field::post_read>
   //            }
   //
   // RegField - <uvm_reg_cbs::post_write> cbs for field,
   //            <uvm_reg_field::post_write>
   //
   // Memory   - <uvm_reg_cbs>::post_write> cbs for mem,
   //            <uvm_mem::post_write>
   //
   // The ~rw~ argument holds information about the operation.
   //
   // - Modifying the ~status~ member modifies the returned status.
   //
   // - Modiying the ~value~ or ~offset~ members has no effect, as
   //   the operation has already completed.
   //
   // See <uvm_reg_item> for details on ~rw~ information.
   //
   virtual task post_write(uvm_reg_item rw); endtask


   // Task: pre_read
   //
   // Callback called before a read operation.
   //
   // All registered ~pre_read~ callback methods are invoked after the
   // invocation of the ~pre_read~ method of associated object (<uvm_reg>,
   // <uvm_reg_field>, <uvm_mem>, or <uvm_reg_backdoor>). If the element being
   // read is a <uvm_reg>, all ~pre_read~ callback methods are invoked before
   // the contained <uvm_reg_fields>. 
   //
   // Backdoor - <uvm_reg_backdoor::pre_read>,
   //            <uvm_reg_cbs>::pre_read> cbs for backdoor
   //
   // Register - <uvm_reg::pre_read>,
   //            <uvm_reg_cbs>::pre_read> cbs for reg,
   //            foreach field {
   //              <uvm_reg_field::pre_read>,
   //              <uvm_reg_cbs::pre_read> cbs for field
   //            }
   //
   // RegField - <uvm_reg_field::pre_read>,
   //            <uvm_reg_cbs::pre_read> cbs for field
   //
   // Memory   - <uvm_mem::pre_read>,
   //            <uvm_reg_cbs>::pre_read> cbs for mem
   //
   // The ~rw~ argument holds information about the operation.
   //
   // - The ~value~ member of ~rw~ is not used has no effect if modified.
   //
   // - For memories, modifying the ~offset~ modifies the offset
   //   used in the operation.
   //
   // - For non-backdoor operations, modifying the access ~path~ or
   //   address ~map~ modifies the actual path or map used in the
   //   operation.
   //
   // See <uvm_reg_item> for details on ~rw~ information.
   //
   virtual task pre_read(uvm_reg_item rw); endtask


   // Task: post_read
   //
   // Callback called after a read operation.
   //
   // All registered ~post_read~ callback methods are invoked before the
   // invocation of the ~post_read~ method of the associated object (<uvm_reg>,
   // <uvm_reg_field>, <uvm_mem>, or <uvm_reg_backdoor>). If the element being read
   // is a <uvm_reg>, all ~post_read~ callback methods are invoked before the
   // contained <uvm_reg_fields>. 
   //
   // Backdoor - <uvm_reg_cbs>::post_read> cbs for backdoor,
   //            <uvm_reg_backdoor::post_read>
   //
   // Register - <uvm_reg_cbs>::post_read> cbs for reg,
   //            <uvm_reg::post_read>,
   //            foreach field {
   //              <uvm_reg_cbs::post_read> cbs for field,
   //              <uvm_reg_field::post_read>
   //            }
   //
   // RegField - <uvm_reg_cbs::post_read> cbs for field,
   //            <uvm_reg_field::post_read>
   //
   // Memory   - <uvm_reg_cbs>::post_read> cbs for mem,
   //            <uvm_mem::post_read>
   //
   // The ~rw~ argument holds information about the operation.
   //
   // - Modifying the readback ~value~ or ~status~ modifies the actual
   //   returned value and status.
   //
   // - Modiying the ~value~ or ~offset~ members has no effect, as
   //   the operation has already completed.
   //
   // See <uvm_reg_item> for details on ~rw~ information.
   //
   virtual task post_read(uvm_reg_item rw); endtask


   // Function: encode
   //
   // Data encoder
   //
   // The registered callback methods are invoked in order of registration
   // after all the ~pre_write~ methods have been called.
   // The encoded data is passed through each invocation in sequence.
   // This allows the ~pre_write~ methods to deal with clear-text data.
   //
   // By default, the data is not modified.
   //
   virtual function void encode(ref uvm_reg_data_t data[]);
   endfunction


   // Function: decode
   //
   // Data decode
   //
   // The registered callback methods are invoked in ~reverse order~
   // of registration before all the ~post_read~ methods are called.
   // The decoded data is passed through each invocation in sequence.
   // This allows the ~post_read~ methods to deal with clear-text data.
   //
   // The reversal of the invocation order is to allow the decoding
   // of the data to be performed in the opposite order of the encoding
   // with both operations specified in the same callback extension.
   // 
   // By default, the data is not modified.
   //
   virtual function void decode(ref uvm_reg_data_t data[]);
   endfunction



endclass


typedef class uvm_reg_backdoor;



// Type: uvm_reg_cb
// Convenience callback type declaration
//
// Use this declaration to register register callbacks rather than
// the more verbose parameterized class
//
typedef uvm_callbacks#(uvm_reg, uvm_reg_cbs) uvm_reg_cb;



// Type: uvm_reg_cb_iter
// Convenience callback iterator type declaration
//
// Use this declaration to iterate over registered register callbacks
// rather than the more verbose parameterized class
//
typedef uvm_callback_iter#(uvm_reg, uvm_reg_cbs) uvm_reg_cb_iter;



// Type: uvm_reg_bd_cb
// Convenience callback type declaration
//
// Use this declaration to register register backdoor callbacks rather than
// the more verbose parameterized class
//
typedef uvm_callbacks#(uvm_reg_backdoor, uvm_reg_cbs) uvm_reg_bd_cb;


// Type: uvm_reg_bd_cb_iter
// Convenience callback iterator type declaration
//
// Use this declaration to iterate over registered register backdoor callbacks
// rather than the more verbose parameterized class
//

typedef uvm_callback_iter#(uvm_reg_backdoor, uvm_reg_cbs) uvm_reg_bd_cb_iter;


// Type: uvm_mem_cb
// Convenience callback type declaration
//
// Use this declaration to register memory callbacks rather than
// the more verbose parameterized class
//
typedef uvm_callbacks#(uvm_mem, uvm_reg_cbs) uvm_mem_cb;

//
// Type: uvm_mem_cb_iter
// Convenience callback iterator type declaration
//
// Use this declaration to iterate over registered memory callbacks
// rather than the more verbose parameterized class
//
typedef uvm_callback_iter#(uvm_mem, uvm_reg_cbs) uvm_mem_cb_iter;


// Type: uvm_reg_field_cb
// Convenience callback type declaration
//
// Use this declaration to register field callbacks rather than
// the more verbose parameterized class
//
typedef uvm_callbacks#(uvm_reg_field, uvm_reg_cbs) uvm_reg_field_cb;


// Type: uvm_reg_field_cb_iter
// Convenience callback iterator type declaration
//
// Use this declaration to iterate over registered field callbacks
// rather than the more verbose parameterized class
//
typedef uvm_callback_iter#(uvm_reg_field, uvm_reg_cbs) uvm_reg_field_cb_iter;



//------------------------------------------------------------------------------
// IMPLEMENTATION
//------------------------------------------------------------------------------


// is_auto_updated

function bit uvm_reg_backdoor::is_auto_updated(uvm_reg_field field);
   return 0;
endfunction


// wait_for_change

task uvm_reg_backdoor::wait_for_change(uvm_object element);
   `uvm_fatal("RegModel", "uvm_reg_backdoor::wait_for_change() method has not been overloaded");
endtask


// start_update_thread

function void uvm_reg_backdoor::start_update_thread(uvm_object element);
   uvm_reg rg;
   if (this.m_update_thread.exists(element)) begin
      this.kill_update_thread(element);
   end
   if (!$cast(rg,element))
     return; // only regs supported at this time

   fork
      begin
         uvm_reg_field fields[$];

         this.m_update_thread[element] = process::self();
         rg.get_fields(fields);
         forever begin
            uvm_status_e status;
            uvm_reg_data_t  val;
            uvm_reg_item r_item = new("bd_r_item");
            r_item.element = rg;
            r_item.element_kind = UVM_REG;
            this.read(r_item);
            if (r_item.status != UVM_IS_OK) begin
               `uvm_error("RegModel", $psprintf("Backdoor read of register '%s' failed.",
                          rg.get_name()));
            end
            foreach (fields[i]) begin
               if (this.is_auto_updated(fields[i])) begin
                  uvm_reg_data_t  fld_val
                     = val >> fields[i].get_lsb_pos();
                  fld_val = fld_val & ((1 << fields[i].get_n_bits())-1);
                  void'(fields[i].predict(fld_val));
                end
            end
            this.wait_for_change(element);
         end
      end
   join_none
endfunction


// kill_update_thread

function void uvm_reg_backdoor::kill_update_thread(uvm_object element);
   if (this.m_update_thread.exists(element)) begin
      this.m_update_thread[element].kill();
      this.m_update_thread.delete(element);
   end
endfunction


// has_update_threads

function bit uvm_reg_backdoor::has_update_threads();
   return this.m_update_thread.num() > 0;
endfunction


// write

task uvm_reg_backdoor::write(uvm_reg_item rw);
   `uvm_fatal("RegModel", "uvm_reg_backdoor::write() method has not been overloaded");
endtask


// read

task uvm_reg_backdoor::read(uvm_reg_item rw);
   do_pre_read(rw);
   read_func(rw);
   do_post_read(rw);
endtask


// read_func

function void uvm_reg_backdoor::read_func(uvm_reg_item rw);
   `uvm_fatal("RegModel", "uvm_reg_backdoor::read_func() method has not been overloaded");
   rw.status = UVM_NOT_OK;
endfunction
