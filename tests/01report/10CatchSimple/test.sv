//---------------------------------------------------------------------- 
//   Copyright 2010 Synopsys, Inc. 
//   All Rights Reserved Worldwide 
// 
//   Licensed under the Apache License, Version 2.0 (the 
//   "License"); you may not use this file except in 
//   compliance with the License.  You may obtain a copy of 
//   the License at 
// 
//       http://www.apache.org/licenses/LICENSE-2.0 
// 
//   Unless required by applicable law or agreed to in 
//   writing, software distributed under the License is 
//   distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR 
//   CONDITIONS OF ANY KIND, either express or implied.  See 
//   the License for the specific language governing 
//   permissions and limitations under the License. 
//----------------------------------------------------------------------


program top;

import uvm_pkg::*;

class my_catcher extends uvm_report_catcher;
   static int seen = 0;
   virtual function action_e catch();
      $write("Caught a message...\n");
      seen++;
      return CAUGHT;
   endfunction
endclass

class test extends uvm_test;

   bit pass = 1;

   `uvm_component_utils(test)

   function new(string name, uvm_component parent = null);
      super.new(name, parent);
   endfunction

   virtual task run();
      $write("UVM TEST EXPECT 2 UVM_ERROR\n");
      `uvm_error("Test", "Error 1...");
      if (my_catcher::seen != 0) begin
         $write("ERROR: Message was caught with no catcher installed!\n");
         pass = 0;
      end
      begin
         my_catcher ctchr = new;
          uvm_report_catcher::add_report_default_catcher(ctchr);

         `uvm_error("Test", "Error 2...");
         if (my_catcher::seen != 1) begin
            $write("ERROR: Message was NOT caught with default catcher installed!\n");
            pass = 0;
         end
         `uvm_info("XYZ", "Medium INFO...", UVM_MEDIUM);
         if (my_catcher::seen != 2) begin
            $write("ERROR: Message was NOT caught with default catcher installed!\n");
            pass = 0;
         end
         `uvm_fatal("Test", "FATAL...");
         if (my_catcher::seen != 3) begin
            $write("ERROR: Message was NOT caught with default catcher installed!\n");
            pass = 0;
         end
      end
      uvm_report_catcher::remove_all_report_catchers();
      `uvm_error("Test", "Error 3...");
      if (my_catcher::seen != 3) begin
         $write("ERROR: Message was caught after all catcher removed!\n");
         pass = 0;
      end
      uvm_top.stop_request();
   endtask

   virtual function void report();
      if (pass) $write("** UVM TEST PASSED **\n");
      else $write("** UVM TEST FAILED! **\n");
   endfunction
endclass


initial
  begin
     run_test();
  end

endprogram
