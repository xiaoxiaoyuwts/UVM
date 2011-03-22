//----------------------------------------------------------------------
//   Copyright 2010-2011 Mentor Graphics Corporation
//   Copyright 2011 Cadence Design Systems, Inc.
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

//----------------------------------------------------------------------
// Title: Resources
//
//
// A resource is a parameterized container that holds arbitrary data.
// Resources can be used to configure components, supply data to
// sequences, or enable sharing of information across disparate parts of
// a testbench.  They are stored using scoping information so their
// visibility can be constrained to certain parts of the testbench.
// Resource containers can hold any type of data, constrained only by
// the data types available in SystemVerilog.  Resources can contain
// scalar objects, class handles, queues, lists, or even virtual
// interfaces.
//
// Resources are stored in a resource database so that each resource can
// be retrieved by name or by type. The databse has both a name table
// and a type table and each resource is entered into both. The database
// is globally accessible.
//
// Each resource has a set of scopes over which it is visible.  The set
// of scopes is represented as a regular expression.  When a resource is
// looked up the scope of the entity doing the looking up is supplied to
// the lookup function.  This is called the ~current scope~.  If the
// current scope is in the set of scopes over which a resource is
// visible then the resource can be retuned in the lookup.
//
// Resources can be looked up by name or by type. To support type lookup
// each resource has a static type handle that uniquely identifies the
// type of each specialized resource container.
//
// Mutliple resources that have the same name are stored in a queue.
// Each resource is pushed into a queue with the first one at the front
// of the queue and each subsequent one behind it.  The same happens for
// multiple resources that have the same type.  The resource queues are
// searched front to back, so those placed earlier in the queue have
// precedence over those placed later.
//
// The precedence of resources with the same name or same type can be
// altered.  One way is to set the ~precedence~ member of the resource
// container to any arbitrary value.  The search algorithm will return
// the resource with the highest precedence.  In the case where there
// are multiple resources that match the search criteria and have the
// same (highest) precedence, the earliest one located in the queue will
// be one returned.  Another way to change the precedence is to use the
// set_priority function to move a resource to either the front or back
// of the queue.
//
// The classes defined here form the low level layer of the resource
// database.  The classes include the resource container and the database
// that holds the containers.  The following set of classes are defined
// here:
//
// <uvm_resource_types>: A class without methods or members, only
// typedefs and enums. These types and enums are used throughout the
// resources facility.  Putting the types in a class keeps them confined
// to a specific name space.
//
// <uvm_resource_options>: policy class for setting options, such
// as auditing, which effect resources.
//
// <uvm_resource_base>: the base (untyped) resource class living in the
// resource database.  This class includes the interface for locking,
// setting a resource as read-only, notification, scope management,
// altering search priority, and managing auditing.
//
// <uvm_resource#(T)>: parameterized resource container.  This class
// includes the interfaces for reading and writing each resource.
// Because the class is parameterized, all the access functions are type
// sace.
//
// <uvm_resource_pool>: the resource database. This is a singleton
// class object.
//----------------------------------------------------------------------

typedef class uvm_resource_base; // forward reference


//----------------------------------------------------------------------
// Class: uvm_resource_types
//
// Provides typedefs and enums used throughout the resources facility.
// This class has no members or methods, only typedefs.  It's used in
// lieu of package-scope types.  When needed, other classes can use
// these types by prefixing their usage with uvm_resource_types::.  E.g.
//
//|  uvm_resource_types::rsrc_q_t queue;
//
//----------------------------------------------------------------------
class uvm_resource_types;

  // types uses for setting overrides
  typedef bit[1:0] override_t;
  typedef enum override_t { TYPE_OVERRIDE = 2'b01,
                            NAME_OVERRIDE = 2'b10 } override_e;

   // general purpose queue of resourcex
  typedef uvm_queue#(uvm_resource_base) rsrc_q_t;

  // enum for setting resource search priority
  typedef enum { PRI_HIGH, PRI_LOW } priority_e;

  // access record for resources.  A set of these is stored for each
  // resource by accessing object.  It's updated for each read/write.
  typedef struct
  {
    time read_time;
    time write_time;
    int unsigned read_count;
    int unsigned write_count;
  } access_t;

endclass



//----------------------------------------------------------------------
// Class: uvm_resource_options
//
// Provides a namespace for managing options for the
// resources facility.  The only thing allowed in this class is static
// local data members and static functions for manipulating and
// retrieving the value of the data members.  The static local data
// members represent options and settings that control the behavior of
// the resources facility.

// Options include:
//
//  * auditing:  on/off
//
//    The default for auditing is on.  You may wish to turn it off to
//    for performance reasons.  With auditing off memory is not
//    consumed for storage of auditing information and time is not
//    spent collecting and storing auditing information.  Of course,
//    during the period when auditing is off no audit trail information
//    is available
//
//----------------------------------------------------------------------
class uvm_resource_options;

  static local bit auditing = 1;

  // Function: turn_on_auditing
  //
  // Turn auditing on for the resource database. This causes all
  // reads and writes to the database to store information about
  // the accesses.

  static function void turn_on_auditing();
    auditing = 1;
  endfunction

  // Function: turn_off_auditing
  //
  // Turn auditing off for the resource database. If auditing is
  // it is not possible to get extra information about resource
  // database accesses.

  static function void turn_off_auditing();
    auditing = 0;
  endfunction

  // Function: is_auditing
  //
  // Returns 1 if the auditing facility is on and 0 if it is off.

  static function bit is_auditing();
    return auditing;
  endfunction

endclass



//----------------------------------------------------------------------
// Class: uvm_resource_base
//
// Non-parameterized base class for resources.  Supports interfaces for
// locking/unlocking, scope matching, and virtual functions for printing
// the resource and for printing the accessor list
//----------------------------------------------------------------------

virtual class uvm_resource_base extends uvm_object;

  protected semaphore sm;
  protected int lock_state;
  protected string scope;
  protected bit modified;
  protected bit read_only;

  // IUS currently does not support the protected keyword.  When
  // it does, comments delimiters can be removed.
  /*protected*/ bit m_is_regex_name=0;

  uvm_resource_types::access_t access[string];

  // variable: precedence
  //
  // This variable is used to associate a precedence that a resource
  // has with respect to other resources which match the same scope
  // and name. Resources are set to the <default_precedence> initially,
  // and may be set to a higher or lower precedence as desired.

  int unsigned precedence;

  // variable: default_precedence
  //
  // The default precedence for an resource that has been created.
  // When two resources have the same precedence, the first resource
  // found has precedence.
  
  static int unsigned default_precedence = 1000;

  // Function: new
  //
  // constructor for uvm_resource_base.  The constructor takes two
  // arguments, the name of the resource and a resgular expression which
  // represents the set of scopes over which this resource is visible.

  function new(string name = "", string s = "*");
    super.new(name);
    set_scope(s);
    sm = new(1);
    lock_state = 1;
    modified = 0;
    read_only = 0;
    precedence = default_precedence;
    if(uvm_has_wildcard(name))
      m_is_regex_name = 1;
  endfunction

  // Function: get_type_handle
  //
  // Pure virtual function that returns the type handle of the resource
  // container.

  pure virtual function uvm_resource_base get_type_handle();


  //-------------------------
  // Group: Locking Interface
  //-------------------------
  //
  // The task <lock> and the functions <try_lock> and <unlock> form a
  // locking interface for resources.  These can be used for thread-safe
  // reads and writes.  The interface methods write_with_lock and
  // read_with_lock and their nonblocking counterparts in
  // <uvm_resource#(T)> (a family of resource subclasses) obey the lock
  // when reading and writing.  See documentation in <uvm_resource#(T)>
  // for more information on put/get.  The lock interface is a wrapper
  // around a local semaphore.


  // Task: lock
  //
  // Retrieves a lock for this resource.  The task blocks until the lock
  // is obtained.

  task lock();
    sm.get();
    lock_state -= 1;
  endtask

  // Function: try_lock
  //
  // Retrives the lock for this resource.  The function is nonblocking,
  // so it will return immediately.  If it was successfull in retrieving
  // the lock then a one is returned, otherwise a zero is returned.

  function bit try_lock();
    bit ok = sm.try_get();
    if(ok)
      lock_state -= 1;
    return ok;
  endfunction

  // Function: unlock
  //
  // Releases the lock held by this semaphore.

  function void unlock();
    sm.put();
    lock_state += 1;
  endfunction


  //---------------------------
  // Group: Read-only Interface
  //---------------------------

  // Function: set_read_only
  //
  // Establishes this resource as a read-only resource.  An attempt
  // to call <uvm_resource#(T)::write> on the resource will cause an error.

  function void set_read_only();
    read_only = 1;
  endfunction

  // function set_read_write
  //
  // Returns the resource to normal read-write capability.
  
  // Implementation question: Not sure if this function is necessary.  
  // Once a resource is set to read_only no one should be able to change 
  // that.  If anyone can flip the read_only bit then the resource is not 
  // truly read_only.

  function void set_read_write();
    read_only = 0;
  endfunction

  // Function: is_read_only
  //
  // Retruns one if this resource has been set to read-only, zero
  // otherwise
  function bit is_read_only();
    return read_only;
  endfunction


  //--------------------
  // Group: Notification
  //--------------------

  // Task: wait_modified
  //
  // This task blocks until the resource has been modified -- that is, a
  // <uvm_resource#(T)::write> operation has been performed.  When a 
  // <uvm_resource#(T)::write> is performed the modified bit is set which 
  // releases the block.  Wait_modified() then clears the modified bit so 
  // it can be called repeatedly.

  task wait_modified();
    wait (modified == 1);
    modified = 0;
  endtask


  //-----------------------
  // Group: Scope Interface
  //-----------------------
  //
  // Each resource has a name, a value and a set of scopes over which it
  // is visible. A scope is a hierarchical entity or a context.  A scope
  // name is a multi-element string that identifies a scope.  Each
  // element refers to a scope context and the elements are separated by
  // dots (.).
  // 
  //|    top.env.agent.monitor
  // 
  // Consider the example above of a scope name.  It consists of four
  // elements: "top", "env", "agent", and "monitor".  The elements are
  // strung together with a dot separating each element.  ~top.env.agent~
  // is the parent of ~top.env.agent.monitor~, ~top.env~ is the parent of
  // ~top.env.agent~, and so on.  A set of scopes can be represented by a
  // set of scope name strings.  A very straightforward way to represent
  // a set of strings is to use regular expressions.  A regular
  // expression is a special string that contains placeholders which can
  // be substituted in various ways to generate or recognize a
  // particular set of strings.  Here are a few simple examples:
  // 
  //|     top\..*	                all of the scopes whose top-level component
  //|                            is top
  //|    top\.env\..*\.monitor	all of the scopes in env that end in monitor;
  //|                            i.e. all the monitors two levels down from env
  //|    .*\.monitor	            all of the scopes that end in monitor; i.e.
  //|                            all the monitors (assuming a naming convention
  //|                            was used where all monitors are named "monitor")
  //|    top\.u[1-5]\.*	        all of the scopes rooted and named u1, u2, u3,
  //                             u4, or u5, and any of their subscopes.
  // 
  // The examples above use posix regular expression notation.  This is
  // a very general and expressive notation.  It is not always the case
  // that so much expressiveness is required.  Sometimes an expression
  // syntax that is easy to read and easy to write is useful, even if
  // the syntax is not as expressive as the full power of posix regular
  // expressions.  A popular substitute for regular expressions is
  // globs.  A glob is a simplified regular expression. It only has
  // three metacharacters -- *, +, and ?.  Character ranges are not
  // allowed and dots are not a metacharacter in globs as they are in
  // regular expressions.  The following table shows glob
  // metacharacters.
  // 
  //|      char	meaning	                regular expression
  //|                                    equivalent
  //|      *	    0 or more characters	.*
  //|      +	    1 or more characters	.+
  //|      ?	    exactly one character	.
  // 
  // Of the examples above, the first three can easily be translated
  // into globs.  The last one cannot.  It relies on notation that is
  // not available in glob syntax.
  // 
  //|    regular expression	    glob equivalent
  //|    ---------------------      ------------------
  //|    top\..*	            top.*
  //|    top\.env\..*\.monitor	    top.env.*.monitor
  //|    .*\.monitor	            *.monitor
  // 
  // The resource facility supports both regular expression and glob
  // syntax.  Regular expressions are identified as such when they 
  // surrounded by '/' characters. For example, ~/^top\.*/~ is
  // interpreted as the regular expression ~^top\.*~, where the
  // surrounding '/' characters have been removed. All other expressions
  // are treated as glob expressions. They are converted from glob 
  // notation to regular expression notation internally.  Regular expression 
  // compilation and matching as well as glob-to-regular expression 
  // conversion are handled by three DPI functions:
  // 
  //|    function int uvm_re_match(string re, string str);
  //|    function void uvm_dump_re_cache();
  //|    function string uvm_glob_to_re(string glob);
  // 
  // uvm_re_match both compiles and matches the regular expression.  It
  // uses internal caching of compiled information so that each match
  // does not necessarily require a new compilation of the regular
  // expression string.  All of the matching is done using regular
  // expressions, so globs are converted to regular expressions and then
  // processed.


  // Function: set_scope
  //
  // Set the value of the regular expression that identifies the set of
  // scopes over which this resource is visible.  If the supplied
  // argument is a glob it will be converted to a regular expression
  // before it is stored.
  //
  function void set_scope(string s);
    scope = uvm_glob_to_re(s);
  endfunction


  // Function: get_scope
  //
  // Retrieve the regular expression string that identifies the set of
  // scopes over which this resource is visible.
  //
  function string get_scope();
    return scope;
  endfunction


  // Function: match_scope
  //
  // Using the regular expression facility, determine if this resource
  // is visible in a scope.  Return one if it is, zero otherwise.
  //
  function bit match_scope(string s);
    int err = uvm_re_match(scope, s);
    return (err == 0);
  endfunction


  //----------------
  // Group: Priority
  //----------------
  //
  // Functions for manipulating the search priority of resources.  The
  // function definitions here are pure virtual and are implemented in
  // derived classes.  The definitons serve as a priority management
  // interface.


  // Function: set priority
  //
  // Change the search priority of the resource based on the value of
  // the priority enum argument.
  //
  pure virtual function void set_priority (uvm_resource_types::priority_e pri);


  //-------------------------
  // Group: Utility Functions
  //-------------------------

  // function convert2string
  //
  // Create a string representation of the resource value.  By default
  // we don't know how to do this so we just return a "?".  Resource
  // specializations are expected to override this function to produce a
  // proper string representation of the resource value.

  function string convert2string();
    return "?";
  endfunction


  // Function: do_print
  //
  // Implementation of do_print which is called by print().

  function void do_print (uvm_printer printer);
    $display("%s [%s] : %s", get_name(), get_scope(), convert2string());
  endfunction


  //-------------------
  // Group: Audit Trail
  //-------------------
  //
  // To find out what is happening as the simulation proceeds, an audit 
  // trail of each read and write is kept. The read and write methods
  // in uvm_resource#(T) each take an accessor argument.  This is a
  // handle to the object that performed that resource access.
  //
  //|    function T read(uvm_object accessor = null);
  //|    function void write(T t, uvm_object accessor = null);
  //
  // The accessor can by anything as long as it is derived from
  // uvm_object.  The accessor object can be a component or a sequence
  // or whatever object from which a read or write was invoked.
  // Typically the ~this~ handle is used as the
  // accessor.  For example:
  //
  //|    uvm_resource#(int) rint;
  //|    int i;
  //|    ...
  //|    rint.write(7, this);
  //|    i = rint.read(this);
  //
  // The accessor's ~get_full_name()~ is stored as part of the audit trail. 
  // This way you can find out what object performed each resource access.
  // Each audit record also includes the time of the access (simulation time)
  // and the particular operation performed (read or write).
  //
  // Auditting is controlled through the <uvm_resource_options> class.


  // Function: print_accessors
  //
  // Dump the access records for this resource
  //
  virtual function void print_accessors();

    string str;
    uvm_component comp;
    uvm_resource_types::access_t access_record;

    if(access.num() == 0)
      return;

    $display("  --------");

    foreach (access[i]) begin
      str = i;
      $write("  %s", str);
      access_record = access[str];
      $display(" reads: %0d @ %0t  writes: %0d @ %0t",
               access_record.read_count,
               access_record.read_time,
               access_record.write_count,
               access_record.write_time);
    end

    $display();

  endfunction


  // Function: init_access_record
  //
  // Initalize a new access record
  //
  function void init_access_record (inout uvm_resource_types::access_t access_record);
    access_record.read_time = 0;
    access_record.write_time = 0;
    access_record.read_count = 0;
    access_record.write_count = 0;
  endfunction

endclass


//----------------------------------------------------------------------
// Class - get_t
//
// Instances of get_t are stored in the history list as a record of each
// get.  Failed gets are indicated with rsrc set to null.  This is part
// of the audit trail facility for resources.
//----------------------------------------------------------------------
class get_t;
  string name;
  string scope;
  uvm_resource_base rsrc;
  time t;
endclass


//----------------------------------------------------------------------
// Class: uvm_resource_pool
//
// The global (singleton) resource database.
//
// Each resource is stored both by primary name and by type handle.  The
// resource pool contains two associative arrays, one with name as the
// key and one with the type handle as the key.  Each associative array
// contains a queue of resources.  Each resource has a regular
// expression that represents the set of scopes over with it is visible.
//
//|  +------+------------+                          +------------+------+
//|  | name | rsrc queue |                          | rsrc queue | type |
//|  +------+------------+                          +------------+------+
//|  |      |            |                          |            |      |
//|  +------+------------+                  +-+-+   +------------+------+
//|  |      |            |                  | | |<--+---*        |  T   |
//|  +------+------------+   +-+-+          +-+-+   +------------+------+
//|  |  A   |        *---+-->| | |           |      |            |      |
//|  +------+------------+   +-+-+           |      +------------+------+
//|  |      |            |      |            |      |            |      |
//|  +------+------------+      +-------+  +-+      +------------+------+
//|  |      |            |              |  |        |            |      |
//|  +------+------------+              |  |        +------------+------+
//|  |      |            |              V  V        |            |      |
//|  +------+------------+            +------+      +------------+------+
//|  |      |            |            | rsrc |      |            |      |
//|  +------+------------+            +------+      +------------+------+
//
// The above diagrams illustrates how a resource whose name is A and
// type is T is stored in the pool.  The pool contains an entry in the
// type map for type T and an entry in the name map for name A.  The
// queues in each of the arrays each contain an entry for the resource A
// whose type is T.  The name map can contain in its queue other
// resources whose name is A which may or may not have the same type as
// our resource A.  Similarly, the type map can contain in its queue
// other resources whose type is T and whose name may or may not be A.
//
// Resources are added to the pool by calling <set>; they are retrieved
// from the pool by calling <get_by_name> or <get_by_type>.  When an object 
// creates a new resource and calls <set> the resource is made available to be
// retrieved by other objects outside of itsef; an object gets a
// resource when it wants to access a resource not currently available
// in its scope.
//
// The scope is stored in the resource itself (not in the pool) so
// whether you get by name or by type the resource's visibility is
// the same.
//
// As an auditing capability, the pool contains a history of gets.  A
// record of each get, whether by <get_by_type> or <get_by_name>, is stored 
// in the audit record.  Both successful and failed gets are recorded. At
// the end of simulation, or any time for that matter, you can dump the
// history list.  This will tell which resources were successfully
// located and which were not.  You can use this information
// to determine if there is some error in name, type, or
// scope that has caused a resource to not be located or to be incorrrectly
// located (i.e. the wrong resource is located).
//
//----------------------------------------------------------------------

class uvm_resource_pool;

  static bit m_has_wildcard_names = 0;
  static local uvm_resource_pool rp = get();

  uvm_resource_types::rsrc_q_t rtab [string];
  uvm_resource_types::rsrc_q_t ttab [uvm_resource_base];

  get_t get_record [$];  // history of gets

  // To make a proper singleton the constructor should be protected.
  // However, IUS doesn't support protected constructors so we'll just
  // the default constructor instead.  If support for protected
  // constructors ever becomes available then this comment can be
  // deleted and the protected constructor uncommented.

  //  protected function new();
  //  endfunction


  // Function: get
  //
  // Returns the singleton handle to the resource pool

  static function uvm_resource_pool get();
    if(rp == null)
      rp = new();
    return rp;
  endfunction


  // Function: spell_check
  //
  // Invokes the spell checker for a string s.  The universe of
  // correctly spelled strings -- i.e. the dictionary -- is the name
  // map.

  function bit spell_check(string s);
    return uvm_spell_chkr#(uvm_resource_types::rsrc_q_t)::check(rtab, s);
  endfunction


  //-----------
  // Group: Set
  //-----------

  // Function: set
  //
  // Add a new resource to the resource pool.  The resource is inserted
  // into both the name map and type map so it can be located by
  // either.
  //
  // An object creates a resources and ~sets~ it into the resource pool.
  // Later, other objects that want to access the resource must ~get~ it
  // from the pool
  //
  // Overrides can be specified using this interface.  Either a name
  // override, a type override or both can be specified.  If an
  // override is specified then the resource is entered at the front of
  // the queue instead of at the back.  It is not recommended that users
  // specify the override paramterer directly, rather they use the
  // <set_override>, <set_name_override>, or <set_type_override>
  // functions.
  //
  function void set (uvm_resource_base rsrc,
                     uvm_resource_types::override_t override = 2'b00);

    uvm_resource_types::rsrc_q_t rq;
    string name;
    uvm_resource_base type_handle;

    // If resource handle is null then there is nothing to do.
    if(rsrc == null)
      return;

    // insert into the name map.  Resources with empty names are
    // anonymous resources and are not entered into the name map
    name = rsrc.get_name();
    if(name != "") begin
      if(rtab.exists(name))
        rq = rtab[name];
      else
        rq = new();

      // Insert the resource into the queue associated with its name.
      // If we are doing a name override then insert it in the front of
      // the queue, otherwise insert it in the back.
      if(override & uvm_resource_types::NAME_OVERRIDE)
        rq.push_front(rsrc);
      else
        rq.push_back(rsrc);

      rtab[name] = rq;
    end

    // insert into the type map
    type_handle = rsrc.get_type_handle();
    if(ttab.exists(type_handle))
      rq = ttab[type_handle];
    else
      rq = new();

    // insert the resource into the queue associated with its type.  If
    // we are doing a type override then insert it in the front of the
    // queue, otherwise insert it in the back of the queue.
    if(override & uvm_resource_types::TYPE_OVERRIDE)
      rq.push_front(rsrc);
    else
      rq.push_back(rsrc);
    ttab[type_handle] = rq;

    //optimization for name lookups. Since most environments never
    //use wildcarded names, don't want to incurr a search penalty
    //unless a wildcarded name has been used.
    if(rsrc.m_is_regex_name)
      m_has_wildcard_names = 1;
  endfunction


  // Function: set_override
  //
  // The resource provided as an argument will be entered into the pool
  // and will override both by name and type.

  function void set_override(uvm_resource_base rsrc);
    set(rsrc, (uvm_resource_types::NAME_OVERRIDE | uvm_resource_types::TYPE_OVERRIDE));
  endfunction


  // Function: set_name_override
  //
  // The resource provided as an argument will entered into the pool
  // using normal precedence in the type map and will override the name.

  function void set_name_override(uvm_resource_base rsrc);
    set(rsrc, uvm_resource_types::NAME_OVERRIDE);
  endfunction


  // Function: set_type_override
  //
  // The resource provided as an argument will be entered into the pool
  // using noraml precedence in the name map and will override the type.

  function void set_type_override(uvm_resource_base rsrc);
    set(rsrc, uvm_resource_types::TYPE_OVERRIDE);
  endfunction


  // function - push_get_record
  //
  // Insert a new record into the get history list.

  function void push_get_record(string name, string scope,
                                  uvm_resource_base rsrc);
    get_t impt;

    // if auditing is turned off then there is no reason
    // to save a get record
    if(!uvm_resource_options::is_auditing())
      return;

    impt = new();

    impt.name  = name;
    impt.scope = scope;
    impt.rsrc  = rsrc;
    impt.t     = $realtime;

    get_record.push_back(impt);
  endfunction


  // function - dump_get_records
  //
  // Format and print the get history list.

  function void dump_get_records();

    get_t record;
    bit success;

    $display("--- resource get records ---");
    foreach (get_record[i]) begin
      record = get_record[i];
      success = (record.rsrc != null);
      $display("get: name=%s  scope=%s  %s @ %0t",
               record.name, record.scope,
               ((success)?"success":"fail"),
               record.t);
    end
  endfunction


  //--------------
  // Group: Lookup
  //--------------
  //
  // This group of functions is for finding resources in the resource database.  
  //
  // <lookup_name> and <lookup_type> locate the set of resources that
  // matches the name or type (respectively) and is visible in the
  // current scope.  These functions return a queue of resources.
  //
  // <get_highest_precedence> traverese a queue of resources and
  // returns the one with the highest precedence -- i.e. the one whose
  // precedence member has the highest value.
  //
  // <get_by_name> and <get_by_type> use <lookup_name> and <lookup_type>
  // (respectively) and <get_highest_precedence> to find the resource with
  // the highest priority that matches the other search criteria.


  // Function: lookup_name
  //
  // Lookup resources by ~name~.  Returns a queue of resources that match
  // the ~name~ and ~scope~.  If no resources match the queue is returned
  // empty. If ~rpterr~ is set then a warning is issued if no matches
  // are found, and the spell checker is invoked on ~name~.

  function uvm_resource_types::rsrc_q_t lookup_name(string scope = "",
                                                    string name,
                                                    bit rpterr = 1);
    uvm_resource_types::rsrc_q_t rq;
    uvm_resource_types::rsrc_q_t q = new();
    uvm_resource_base rsrc;
    uvm_resource_base r;

    // resources with empty names are anonymous and do not exist in the name map
    if(name == "")
      return q;

    // Does an entry in the name map exist with the specified name?
    // If not, then we're done
    if((rpterr && !spell_check(name)) || (!rpterr && !rtab.exists(name))) begin
      return q;
    end

    rsrc = null;
    rq = rtab[name];
    for(int i=0; i<rq.size(); ++i) begin 
      r = rq.get(i);
      if(r.match_scope(scope))
        q.push_back(r);
    end

    return q;

  endfunction


  // Function: get_highest_precedence
  //
  // Traverse a queue, ~q~, of resources and return the one with the highest
  // precedence.  In the case where there exists more than one resource
  // with the highest precedence value, the first one that has that
  // precedence will be the one that is returned.

  function uvm_resource_base get_highest_precedence(ref uvm_resource_types::rsrc_q_t q);

    uvm_resource_base rsrc;
    uvm_resource_base r;
    int unsigned i;
    int unsigned prec;

    if(q.size() == 0)
      return null;

    // get the first resources in the queue
    rsrc = q.get(0);
    prec = rsrc.precedence;

    // start searching from the second resource
    for(int i = 1; i < q.size(); ++i) begin
      r = q.get(i);
      if(r.precedence > prec) begin
        rsrc = r;
        prec = r.precedence;
      end
    end

    return rsrc;

  endfunction


  // Function: get_by_name
  //
  // Lookup a resource by ~name~ and ~scope~.  Whether the get succeeds
  // or fails, save a record of the get attempt.  The ~rpterr~ flag
  // indicates whether to report errors or not.  Essentially, it
  // serves as a verbose flag.  If set then the spell checker will be
  // invoked and warnings about multiple resources will be produced.

  function uvm_resource_base get_by_name(string scope = "",
                                         string name,
                                         bit rpterr = 1);

    uvm_resource_types::rsrc_q_t q;
    uvm_resource_base rsrc;

    q = lookup_name(scope, name, rpterr);

    if(q.size() == 0) begin
      push_get_record(name, scope, null);
      return null;
    end

    rsrc = get_highest_precedence(q);
    push_get_record(name, scope, rsrc);
    return rsrc;
    
  endfunction


  // Function: lookup_type
  //
  // Lookup resources by type. Return a queue of resources that match
  // the ~type_handle~ and ~scope~.  If no resources match then the returned
  // queue is empty.

  function uvm_resource_types::rsrc_q_t lookup_type(string scope = "",
                                                    uvm_resource_base type_handle);

    uvm_resource_types::rsrc_q_t q = new();
    uvm_resource_types::rsrc_q_t rq;
    uvm_resource_base r;
    int unsigned i;

    if(type_handle == null || !ttab.exists(type_handle)) begin
      return q;
    end

    rq = ttab[type_handle];
    for(int i = 0; i < rq.size(); ++i) begin 
      r = rq.get(i);
      if(r.match_scope(scope))
        q.push_back(r);
    end

    return q;

  endfunction


  // Function: get_by_type
  //
  // Lookup a resource by ~type_handle~ and ~scope~.  Insert a record into
  // the get history list whether or not the get succeeded.

  function uvm_resource_base get_by_type(string scope = "",
                                         uvm_resource_base type_handle);

    uvm_resource_types::rsrc_q_t q;
    uvm_resource_base rsrc;

    q = lookup_type(scope, type_handle);

    if(q.size() == 0) begin
      push_get_record("<type>", scope, null);
      return null;
    end

    rsrc = q.get(0);
    push_get_record("<type>", scope, rsrc);
    return rsrc;
    
  endfunction

  // Function: lookup_regex_names
  //
  // This utility function answers the question, for a given ~name~ and
  // ~scope~, what are all of the resources with a matching name (where the
  // resource name may be a regular expression) and a matching scope
  // (where the resoucre scope may be a regular expression). ~name~ and
  // ~scope~ are explicit values.

  function uvm_resource_types::rsrc_q_t lookup_regex_names(string scope,
                                                           string name);

    uvm_resource_types::rsrc_q_t rq;
    uvm_resource_types::rsrc_q_t result_q;
    int unsigned i;
    uvm_resource_base r;

    //For the simple case where no wildcard names exist, then we can
    //just return the queue associated with name.
    if(!m_has_wildcard_names) begin
      result_q = lookup_name(scope, name, 0);
      return result_q;
    end

    result_q = new();

    foreach (rtab[re]) begin
      rq = rtab[re];
      for(i = 0; i < rq.size(); i++) begin
        r = rq.get(i);
        if(uvm_re_match(uvm_glob_to_re(re),name) == 0)
          if(r.match_scope(scope))
            result_q.push_back(r);
      end
    end
    return result_q;
  endfunction

  // Function: lookup_regex
  //
  // Looks for all the resources whose name matches the regular
  // expression argument and whose scope matches the current scope.

  function uvm_resource_types::rsrc_q_t lookup_regex(string re, scope);

    uvm_resource_types::rsrc_q_t rq;
    uvm_resource_types::rsrc_q_t result_q;
    int unsigned i;
    uvm_resource_base r;

    re = uvm_glob_to_re(re);
    result_q = new();

    foreach (rtab[name]) begin
      if(!uvm_re_match(re, name))
        continue;
      rq = rtab[name];
      for(i = 0; i < rq.size(); i++) begin
        r = rq.get(i);
        if(r.match_scope(scope))
          result_q.push_back(r);
      end
    end

    return result_q;

  endfunction

  // Function: lookup_scope
  //
  // This is a utility function that answers the question: For a given
  // ~scope~, what resources are visible to it?  Locate all the resources
  // that are visible to a particular scope.  This operation could be
  // quite expensive, as it has to traverse all of the resources in the
  // database.

  function uvm_resource_types::rsrc_q_t lookup_scope(string scope);

    uvm_resource_types::rsrc_q_t rq;
    uvm_resource_base r;
    int unsigned i;

    int unsigned err;
    uvm_resource_types::rsrc_q_t q = new();

    foreach (rtab[name]) begin
      rq = rtab[name];
      for(int i = 0; i < rq.size(); ++i) begin
        r = rq.get(i);
        if(r.match_scope(scope))
          q.push_back(r);
      end
    end

    return q;
    
  endfunction

  //--------------------
  // Group: Set Priority
  //--------------------
  //
  // Functions for altering the search priority of resources.  Resources
  // are stored in queues in the type and name maps.  When retrieving
  // resoures, either by type or by name, the resource queue is search
  // from front to back.  The first one that matches the search criteria
  // is the one that is returned.  The ~set_priority~ functions let you
  // change the order in which resources are searched.  For any
  // particular resource, you can set its priority to UVM_HIGH, in which
  // case the resource is moved to the front of the queue, or to UVM_LOW in
  // which case the resource is moved to the back of the queue.


  // function- set_priority_queue
  //
  // This function handles the mechanics of moving a resource to either
  // the front or back of the queue.

  local function void set_priority_queue(uvm_resource_base rsrc,
                                         ref uvm_resource_types::rsrc_q_t q,
                                         uvm_resource_types::priority_e pri);

    uvm_resource_base r;
    int unsigned i;

    string msg;
    string name = rsrc.get_name();

    for(i = 0; i < q.size(); i++) begin
      r = q.get(i);
      if(r == rsrc) break;
    end

    if(r != rsrc) begin
      $sformat(msg, "Handle for resource named %s is not in the name name; cannot change its priority", name);
      uvm_report_error("NORSRC", msg);
      return;
    end

    q.delete(i);

    case(pri)
      uvm_resource_types::PRI_HIGH: q.push_front(rsrc);
      uvm_resource_types::PRI_LOW:  q.push_back(rsrc);
    endcase

  endfunction


  // Function: set_priority_type
  //
  // Change the priority of the ~rsrc~ based on the value of ~pri~, the
  // priority enum argument.  This function changes the priority only in
  // the type map, leavint the name map untouched.

  function void set_priority_type(uvm_resource_base rsrc,
                                  uvm_resource_types::priority_e pri);

    uvm_resource_base type_handle;
    string msg;
    uvm_resource_types::rsrc_q_t q;

    if(rsrc == null) begin
      uvm_report_warning("NULLRASRC", "attempting to change the serach priority of a null resource");
      return;
    end

    type_handle = rsrc.get_type_handle();
    if(!ttab.exists(type_handle)) begin
      $sformat(msg, "Type handle for resrouce named %s not found in type map; cannot change its search priority", rsrc.get_name());
      uvm_report_error("RNFTYPE", msg);
      return;
    end

    q = ttab[type_handle];
    set_priority_queue(rsrc, q, pri);
  endfunction


  // Function: set_priority_name
  //
  // Change the priority of the ~rsrc~ based on the value of ~pri~, the
  // priority enum argument.  This function changes the priority only in
  // the name map, leaving the type map untouched.

  function void set_priority_name(uvm_resource_base rsrc,
                                  uvm_resource_types::priority_e pri);

    string name;
    string msg;
    uvm_resource_types::rsrc_q_t q;

    if(rsrc == null) begin
      uvm_report_warning("NULLRASRC", "attempting to change the serach priority of a null resource");
      return;
    end

    name = rsrc.get_name();
    if(!rtab.exists(name)) begin
      $sformat(msg, "Resrouce named %s not found in name map; cannot change its search priority", name);
      uvm_report_error("RNFNAME", msg);
      return;
    end

    q = rtab[name];
    set_priority_queue(rsrc, q, pri);

  endfunction


  // Function: set_priority
  //
  // Change the search priority of the ~rsrc~ based on the value of ~pri~,
  // the priority enum argument.  This function changes the priority in
  // both the name and type maps.

  function void set_priority (uvm_resource_base rsrc,
                              uvm_resource_types::priority_e pri);
    set_priority_type(rsrc, pri);
    set_priority_name(rsrc, pri);
  endfunction


  //--------------------------------------------------------------------
  // Group: Debug
  //--------------------------------------------------------------------

  // Function: find_unused_resources
  //
  // Locate all the resources that have at least one write and no reads

  function uvm_resource_types::rsrc_q_t find_unused_resources();

    uvm_resource_types::rsrc_q_t rq;
    uvm_resource_types::rsrc_q_t q = new;
    int unsigned i;
    uvm_resource_base r;
    uvm_resource_types::access_t a;
    int reads;
    int writes;

    foreach (rtab[name]) begin
      rq = rtab[name];
      for(int i=0; i<rq.size(); ++i) begin
        r = rq.get(i);
        reads = 0;
        writes = 0;
        foreach(r.access[str]) begin
          a = r.access[str];
          reads += a.read_count;
          writes += a.write_count;
        end
        if(writes > 0 && reads == 0)
          q.push_back(r);
      end
    end

    return q;

  endfunction


  // Function: print_resources
  //
  // Print the resources that are in a single queue, ~rq~.  This is a utility
  // function that can be used to print any collection of resources
  // stored in a queue.  The ~audit~ flag determines whether or not the
  // audit trail is printed for each resource along with the name,
  // value, and scope regular expression.

  function void print_resources(uvm_resource_types::rsrc_q_t rq, bit audit = 0);

    int unsigned i;
    uvm_resource_base r;
    static uvm_line_printer printer = new();

    printer.knobs.separator="";
    printer.knobs.full_name=0;
    printer.knobs.identifier=0;
    printer.knobs.type_name=0;
    printer.knobs.reference=0;

    if(rq == null && rq.size() == 0) begin
      $display("<none>");
      return;
    end

    for(int i=0; i<rq.size(); ++i) begin
      r = rq.get(i);
      r.print(printer);
      if(audit == 1)
        r.print_accessors();
    end

  endfunction


  // Function: dump
  //
  // dump the entire resource pool.  The resource pool is traversed and
  // each resource is printed.  The utility function print_resources()
  // is used to initiate the printing. If the ~audit~ bit is set then
  // the audit trail is dumped for each resource.

  function void dump(bit audit = 0);

    uvm_resource_types::rsrc_q_t rq;
    string name;

    $display("\n=== resource pool ===");

    foreach (rtab[name]) begin
      rq = rtab[name];
      print_resources(rq, audit);
    end

    $display("=== end of resource pool ===");

  endfunction

endclass



//------------------------------------------------------------------------------
//
// CLASS: uvm_resource_converter
//
// The uvm_resource_converter class provides a policy object for doing
// convertion from resource value to string.
//
//------------------------------------------------------------------------------
class uvm_resource_converter #(type T=int);

   // Function: convert2string
   // Convert a value of type ~T~ to a string that can be displayed.
   //
   // By default, returns the name of the type
   //
   virtual function string convert2string(T val);
      return {"(", $typename(T), ") ?"};;
   endfunction
endclass

   
//----------------------------------------------------------------------
// Class: uvm_resource #(T)
//
// Parameterized resource.  Provides essential access methods to read
// from and write to the resource database.  Also provides locking access 
// methods including.
//
//----------------------------------------------------------------------


class uvm_resource #(type T=int) extends uvm_resource_base;

  typedef uvm_resource#(T) this_type;

  // singleton handle that represents the type of this resource
  static this_type my_type = get_type();

  // Can't be rand since things like rand strings are not legal.
  protected T val;

  function new(string name="", scope="");
    super.new(name, scope);
  endfunction

  // Singleton used to convert this resource to a string
  static uvm_resource_converter#(T) m_r2s;

  // Function: set_converter
  // Specify how to convert the value of a resource of this type to a string
  //
  // If not specified (or set to ~null~),
 //  the name of the resource type is displayed,
  // not the content of the resource.
  // Default conversion functions are specified for the built-in type.
  //
  static function void set_converter(uvm_resource_converter#(T) r2s);
    m_r2s = r2s;
  endfunction

   
  function string convert2string();
    if (m_r2s != null)
      return m_r2s.convert2string(val);
     
    return {"(", $typename(T), ") ?"};
  endfunction




  //----------------------
  // Group: Type Interface
  //----------------------
  //
  // Resources can be identified by type using a static type handle.
  // The parent class provides the virtual function interface
  // <get_type_handle>.  Here we implement it by returning the static type
  // handle.

  // Function: get_type
  //
  // Static function that returns the static type handle.  The return
  // type is this_type, which is the type of the parameterized class.

  static function this_type get_type();
    if(my_type == null)
      my_type = new();
    return my_type;
  endfunction

  // Function: get_type_handle
  //
  // Returns the static type handle of this resource in a polymorphic
  // fashion.  The return type of get_type_handle() is
  // uvm_resource_base.  This function is not static and therefore can
  // only be used by instances of a parameterized resource.

  function uvm_resource_base get_type_handle();
    return get_type();
  endfunction

  //-------------------------
  // Group: Set/Get Interface
  //-------------------------
  //
  // uvm_resource#(T) provides an interface for setting and getting a
  // resources.  Specifically, a resource can insert itself into the
  // resource pool.  It doesn't make sense for a resource to get itself,
  // since you can't call a funtion on a handle you don't have.
  // However, a static get interface is provided as a convenience.  This
  // obviates the need for the user to get a handle to the global
  // resource pool as this is done for him here.

  // Function: set
  //
  // Simply put this resource into the global resource pool

  function void set();
    uvm_resource_pool rp = uvm_resource_pool::get();
    rp.set(this);
  endfunction

  
  // Function: set_override
  //
  // Put a resource into the global resource pool as an override.  This
  // means it gets put at the head of the list and is searched before
  // other existing resources that occupy the same position in the name
  // map or the type map.  The default is to override both the name and
  // type maps.  However, using the ~override~ argument you can specify
  // that either the name map or type map is overridden.

  function void set_override(uvm_resource_types::override_t override = 2'b11);
    uvm_resource_pool rp = uvm_resource_pool::get();
    rp.set(this, override);
  endfunction


  // Function: get_by_name
  //
  // looks up a resource by ~name~ in the name map. The first resource
  // with the specified name that is visible in the specified ~scope~ is
  // returned, if one exists.  The ~rpterr~ flag indicates whether or not
  // an error should be reported if the search fails.  If ~rpterr~ is set
  // to one then a failure message is issued, including suggested
  // spelling alternatives, based on resource names that exist in the
  // database, gathered by the spell checker.

  static function this_type get_by_name(string scope,
                                        string name,
                                        bit rpterr = 1);

    uvm_resource_pool rp = uvm_resource_pool::get();
    uvm_resource_base rsrc_base;
    this_type rsrc;
    string msg;

    rsrc_base = rp.get_by_name(scope, name, rpterr);
    if(rsrc_base == null)
      return null;

    if(!$cast(rsrc, rsrc_base)) begin
      $sformat(msg, "Resource with name %s in scope %s has incorrect type", name, scope);
      `uvm_warning("RSRCTYPE", msg);
      return null;
    end

    return rsrc;
    
  endfunction


  // Function: get_by_type
  //
  // looks up a resource by ~type_handle~ in the type map. The first resource
  // with the specified ~type_handle~ that is visible in the specified ~scope~ is
  // returned, if one exists. Null is returned if there is no resource matching
  // the specifications.

  static function this_type get_by_type(string scope = "",
                                        uvm_resource_base type_handle);

    uvm_resource_pool rp = uvm_resource_pool::get();
    uvm_resource_base rsrc_base;
    this_type rsrc;
    string msg;

    if(type_handle == null)
      return null;

    rsrc_base = rp.get_by_type(scope, type_handle);
    if(rsrc_base == null)
      return null;

    if(!$cast(rsrc, rsrc_base)) begin
      $sformat(msg, "Resource with specified type handle in scope %s was not located", scope);
      `uvm_warning("RSRCNF", msg);
      return null;
    end

    return rsrc;

  endfunction
  

  //----------------------------
  // Group: Read/Write Interface
  //----------------------------
  //
  // <read> and <write> provide a type-safe interface for getting and
  // setting the object in the resource container.  The interface is
  // type safe because the value argument for <write> and the return
  // value of <read> are T, the type supplied in the class parameter.
  // If either of these functions is used in an incorrect type context
  // the compiler will complain.


  // Function: read
  //
  // Return the object stored in the resource container.  If an ~accessor~
  // object is supplied then also update the accessor record for this
  // resource.

  function T read(uvm_object accessor = null);

    string str;

    // Has the resource been locked by the locking interface?  If so,
    // issue an error.  Since we are doing a read which does not modify
    // the contents of the resource, why issue an error and not just a
    // warning?  The resource may be undergoing a value change and so we
    // cannot be sure that the current value is the same as when the
    // resource is subsequently unlocked. It may be or it may not be.
    // Since we can't tell the user may be getting the incorrect value.

    if(lock_state == 0) begin
      string msg;
      $sformat(msg, "Resource %s is being read by the non-locking interface while it is locked by the locking interface.  This could result in the incorrect value being returned", get_name());
      uvm_report_error("LOCKED_READ", msg);
    end

    // If an accessor object is supplied then get the accessor record.
    // Otherwise create a new access record.  In either case populate
    // the access record with information about this access.  Check
    // first to make sure that auditing is turned on.

    if(uvm_resource_options::is_auditing()) begin
      if(accessor != null) begin
        uvm_resource_types::access_t access_record;
        str = accessor.get_full_name();
        if(access.exists(str))
          access_record = access[str];
        else
          init_access_record(access_record);
        access_record.read_count++;
        access_record.read_time = $realtime;
        access[str] = access_record;
      end
    end

    // get the value
    return val;
  endfunction


  // Function: write
  //
  // Modify the object stored in this resource container.  If the
  // resource is read-only then issue an error message and return
  // without modifying the object in the container.  If the resource is
  // not read-only and an ~accessor~ object has been supplied then also
  // update the accessor record.  Lastly, replace the object value in the
  // container with the value supplied as the  argument, ~t~, and 
  // release any processes blocked on <uvm_resource_base::wait_modified>.

  function void write(T t, uvm_object accessor = null);

    if(is_read_only()) begin
      uvm_report_error("resource", $psprintf("resource %s is read only -- cannot modify", get_name()));
      return;
    end

    if(lock_state == 0) begin
      string msg;
      $sformat(msg, "Resource %s is locked and cannot be modified at this time", get_name());
      uvm_report_error("LOCKED_WRITE", msg);
      return;
    end

    // If an accessor object is supplied then get the accessor record.
    // Otherwise create a new access record.  In either case populate
    // the access record with information about this access.  Check
    // first that auditing is turned on

    if(uvm_resource_options::is_auditing()) begin
      if(accessor != null) begin
        uvm_resource_types::access_t access_record;
        string str;
        if(access.exists(str))
          access_record = access[str];
        else
          init_access_record(access_record);
        access_record.write_count++;
        access_record.write_time = $realtime;
        access[str] = access_record;
      end
    end

    // set the value and set the dirty bit
    val = t;
    modified = 1;
  endfunction


  //----------------
  // Group: Priority
  //----------------
  //
  // Functions for manipulating the search priority of resources.  These
  // implementations of the interface defined in the base class delegate
  // to the resource pool. 


  // Function: set priority
  //
  // Change the search priority of the resource based on the value of
  // the priority enum argument, ~pri~.

  function void set_priority (uvm_resource_types::priority_e pri);
    uvm_resource_pool rp = uvm_resource_pool::get();
    rp.set_priority(this, pri);
  endfunction


  //-------------------------
  // Group: Locking Interface
  //-------------------------
  //
  // This interface is optional, you can choose to lock a resource or
  // not. These methods are wrappers around the read/write interface.
  // The difference between read/write interface and the locking
  // interface is the use of a semaphore to guarantee exclusive access.


  // Task: read_with_loc;
  //
  // Locking version of read().  Like read(), this returns the contents
  // of the resource container.  In addtion it obeys the lock.

  task read_with_lock (output T t, input uvm_object accessor = null);
    lock();
    t = read(accessor);
    unlock();
  endtask


  // Function: try_read_with_lock
  //
  // Nonblocking form of read_with_lock().  If the lock is availble it
  // grabs the lock and returns one.  If the lock is not available then
  // it returns a 0.  In either case the return is immediate with no
  // blocking.

  function bit try_read_with_lock(output T t, input uvm_object accessor = null);
    if(!try_lock())
      return 0;
    t = read(accessor);
    unlock();
    return 1;
  endfunction


  // Task: write_with_lock
  //
  // Locking form of write().  Like write(), write_with_lock() sets the
  // contents of the resource container.  In addition it locks the
  // resource before doing the write and unlocks it when the write is
  // complete.  If the lock is currently not available write_with_lock()
  // will block until it is.

  task write_with_lock (input T t, uvm_object accessor = null);
    lock();
    write(t, accessor);
    unlock();
  endtask


  // Function: try_write_with_lock
  //
  // Nonblocking form of write_with_lock(). If the lock is available
  // then the write() occurs immediately and a one is returned.  If the
  // lock is not available then the write does not occur and a zero is
  // returned.  IN either case try_write_with_lock() returns immediately
  // with no blocking.

  function bit try_write_with_lock(input T t, uvm_object accessor = null);
    if(!try_lock())
      return 0;
    write(t, accessor);
    unlock();
    return 1;
  endfunction


  // Function: get_highest_precedence
  //
  // In a queue of resources, locate the first one with the highest
  // precedence whose type is T.  This function is static so that it can
  // be called from anywhere.

  static function this_type get_highest_precedence(ref uvm_resource_types::rsrc_q_t q);

    this_type rsrc;
    this_type r;
    int unsigned i;
    int unsigned prec;
    int unsigned first;

    if(q.size() == 0)
      return null;

    first = 0;
    rsrc = null;
    prec = 0;

    // Locate first resources in the queue whose type is T
    for(first = 0; first < q.size() && !$cast(rsrc, q.get(first)); first++);

    // no resource in the queue whose type is T
    if(rsrc == null)
      return null;

    prec = rsrc.precedence;

    // start searching from the next resource after the first resource
    // whose type is T
    for(int i = first+1; i < q.size(); ++i) begin
      if($cast(r, q.get(i))) begin
        if(r.precedence > prec) begin
          rsrc = r;
          prec = r.precedence;
        end
      end
    end

    return rsrc;

  endfunction

endclass


//----------------------------------------------------------------------
// static global resource pool handle
//----------------------------------------------------------------------
const uvm_resource_pool uvm_resources = uvm_resource_pool::get();



//----------------------------------------------------------------------
//
// CLASS: uvm_resource_default_converter
// Define a default resource value converter using '%p'.
//
// May be used for almost all types, except virtual interfaces.
// Default resource converters are already defined for the
// built-in singular types using the <uvm_resource_default_converters>
// class.
//
//----------------------------------------------------------------------

class uvm_resource_default_converter#(type T=int) extends uvm_resource_converter#(T);

   virtual function string convert2string(T val);
      return $sformatf("(%s) %0p", $typename(T), val);
   endfunction
   
   local static bit m_singleton = register();
   local function new();
      uvm_resource#(T)::set_converter(this);
   endfunction

   // Function: register
   // Register the default resource value conversion function
   // for this resource type.
   //
   //| void'(uvm_resource_default_converter#(bit[7:0])::register());
   //
   static function bit register();
      if (!m_singleton) begin
         uvm_resource_default_converter#(T) _this = new();
         m_singleton = 1;
      end
      return 1;
   endfunction
endclass


//----------------------------------------------------------------------
//
// CLASS: uvm_resource_class_converter
// Define a default resource value converter using convert2string() method
//
// May be used for all class types that contain a ~convert2string()~ method,
// such as <uvm_object>.
//
//----------------------------------------------------------------------

class uvm_resource_class_converter#(type T=int) extends uvm_resource_converter#(T);

   virtual function string convert2string(T val);
      return $sformatf("(%s) %0s", $typename(T),
                       (val == null) ? "(null)" : val.convert2string());
   endfunction
   
   local static bit m_singleton = register();
   local function new();
      uvm_resource#(T)::set_converter(this);
   endfunction

   // Function: register
   // Register the default resource value conversion function
   // for this resource type.
   //
   //| void'(uvm_resource_class_converter#(my_obj)::register());
   //
   static function bit register();
      if (!m_singleton) begin
         uvm_resource_class_converter#(T) _this = new();
         m_singleton = 1;
      end
      return 1;
   endfunction
endclass


//----------------------------------------------------------------------
//
// CLASS: uvm_resource_sprint_converter
// Define a default resource value converter using sprint() method
//
// May be used for all class types that contain a ~sprint()~ method,
// such as <uvm_object>.
//
//----------------------------------------------------------------------

class uvm_resource_sprint_converter#(type T=int) extends uvm_resource_converter#(T);

   virtual function string convert2string(T val);
      return $sformatf("(%s) %0s", $typename(T),
                       (val == null) ? "(null)" : {"\n",val.sprint()});
   endfunction
   
   local static bit m_singleton = register();
   local function new();
      uvm_resource#(T)::set_converter(this);
   endfunction

   // Function: register
   // Register the default resource value conversion function
   // for this resource type.
   //
   //| void'(uvm_resource_sprint_converter#(my_obj)::register());
   //
   static function bit register();
      if (!m_singleton) begin
         uvm_resource_sprint_converter#(T) _this = new();
         m_singleton = 1;
      end
      return 1;
   endfunction
endclass


//
// CLASS: uvm_resource_default_converters
// Singleton used to register default resource value converters
// for the built-in singular types.
//
class uvm_resource_default_converters;
   
   local static bit m_singleton = register();
   local function new();
   endfunction

   // Function: register
   // Explicitly initialize the singleton to eliminate race conditions
   //
   static function bit register();
      if (!m_singleton) begin

         `define __built_in(T) uvm_resource_default_converter#(T)::register();
            
         `__built_in(shortint);
         `__built_in(int);
         `__built_in(longint);
         `__built_in(byte);
         `__built_in(bit);
         `__built_in(logic);
         `__built_in(reg);
         `__built_in(integer);
         `__built_in(time);
         `__built_in(real);
         `__built_in(shortreal);
         `__built_in(realtime);
         `__built_in(string);

         `undef __built_in

         m_singleton = 1;
      end
      return 1;
   endfunction
endclass
