%%%----------------------------------------------------------------------
%%% File        : aerospike_constants.hrl
%%% Author      : Aleksey Morarash <aleksey.morarash@gmail.com>
%%% Description : constant value definitions for Aerospike wire protocol.
%%% Created     : 02 May 2016
%%%----------------------------------------------------------------------

-ifndef(_AEROSPIKE_CONSTANTS).
-define(_AEROSPIKE_CONSTANTS, true).

%% Current Aerospike protocol version
-define(VERSION, 2).

%% Message types
-define(AerospikeInfo, 1).
-define(AerospikeMessage, 3).

%% Info1 flags
-define(AS_MSG_INFO1_READ, 1). %% contains a read operation
-define(AS_MSG_INFO1_GET_ALL, 2). %% get all bins' data
-define(AS_MSG_INFO1_BATCH, 4). %% new batch protocol
-define(AS_MSG_INFO1_XDR, 16). %% operation is performed by XDR
-define(AS_MSG_INFO1_NOBINDATA, 32). %% do not read the bin information
-define(AS_MSG_INFO1_CONSISTENCY_LEVEL_B0, 64). %% read consistency level - bit 0
-define(AS_MSG_INFO1_CONSISTENCY_LEVEL_B1, 128). %% read consistency level - bit 1
-define(AS_READ_CONSISTENCY_LEVEL_ONE, 2#00).
-define(AS_READ_CONSISTENCY_LEVEL_ALL, 2#01).

-define(
   info1weights,
   [{read, ?AS_MSG_INFO1_READ},
    {get_all, ?AS_MSG_INFO1_GET_ALL},
    {batch, ?AS_MSG_INFO1_BATCH},
    {xdr, ?AS_MSG_INFO1_XDR},
    {nobindata, ?AS_MSG_INFO1_NOBINDATA},
    {read_consistency_level_all, 64}
   ]).

%% Info2 flags
-define(AS_MSG_INFO2_WRITE, 1). %% contains a write operation
-define(AS_MSG_INFO2_DELETE, 2). %% delete record
-define(AS_MSG_INFO2_GENERATION, 4). %% pay attention to the generation
-define(AS_MSG_INFO2_GENERATION_GT, 8). %% apply write if new generation >= old, good for restore
-define(AS_MSG_INFO2_CREATE_ONLY, 32). %% write record only if it doesn't exist
-define(AS_MSG_INFO2_BIN_CREATE_ONLY, 64). %% write bin only if it doesn't exist
-define(AS_MSG_INFO2_RESPOND_ALL_OPS, 128). %% all bin ops (read, write, or modify)
                                            %% require a response, in request order

-define(
   info2weights,
   [{write, ?AS_MSG_INFO2_WRITE},
    {delete, ?AS_MSG_INFO2_DELETE},
    {generation, ?AS_MSG_INFO2_GENERATION},
    {generation_gt, ?AS_MSG_INFO2_GENERATION_GT},
    {create_only, ?AS_MSG_INFO2_CREATE_ONLY},
    {bin_create_only, ?AS_MSG_INFO2_BIN_CREATE_ONLY},
    {respond_all_ops, ?AS_MSG_INFO2_RESPOND_ALL_OPS}
   ]).

%% Info3 flags
-define(AS_MSG_INFO3_LAST, 1). %% this is the last of a multi-part message
-define(AS_MSG_INFO3_COMMIT_LEVEL_B0, 2). %% write commit level - bit 0
-define(AS_MSG_INFO3_COMMIT_LEVEL_B1, 4). %% write commit level - bit 1
-define(AS_WRITE_COMMIT_LEVEL_ALL, 2#00).
-define(AS_WRITE_COMMIT_LEVEL_MASTER, 2#01).
-define(AS_MSG_INFO3_UPDATE_ONLY, 8). %% update existing record only, do not create new record
-define(AS_MSG_INFO3_CREATE_OR_REPLACE, 16). %% completely replace existing record, or create new record
-define(AS_MSG_INFO3_REPLACE_ONLY, 32). %% completely replace existing record, do not create new record
-define(AS_MSG_INFO3_BIN_REPLACE_ONLY, 64). %% replace existing bin, do not create new bin

-define(
   info3weights,
   [{last, ?AS_MSG_INFO3_LAST},
    {write_commit_level_master, 2},
    {update_only, ?AS_MSG_INFO3_UPDATE_ONLY},
    {create_or_replace, ?AS_MSG_INFO3_CREATE_OR_REPLACE},
    {replace_only, ?AS_MSG_INFO3_REPLACE_ONLY},
    {bin_replace_only, ?AS_MSG_INFO3_BIN_REPLACE_ONLY}
   ]).

%% allowed field types
-define(AS_MSG_FIELD_TYPE_NAMESPACE, 0). %% namespace
-define(AS_MSG_FIELD_TYPE_SET, 1). %% a particular set within the namespace
-define(AS_MSG_FIELD_TYPE_KEY, 2). %% the key
-define(AS_MSG_FIELD_TYPE_BIN, 3). %% (Unused.)
-define(AS_MSG_FIELD_TYPE_DIGEST_RIPE, 4). %% the RIPEMD160 digest representing the key (20 bytes)
-define(AS_MSG_FIELD_TYPE_GU_TID, 5). %% (Unused.)
-define(AS_MSG_FIELD_TYPE_DIGEST_RIPE_ARRAY, 6). %% an array of digests
-define(AS_MSG_FIELD_TYPE_TRID, 7). %% transaction ID
-define(AS_MSG_FIELD_TYPE_SCAN_OPTIONS, 8). %% scan operation options
-define(AS_MSG_FIELD_TYPE_INDEX_NAME, 21). %% secondary index name
-define(AS_MSG_FIELD_TYPE_INDEX_RANGE, 22). %% secondary index query range
-define(AS_MSG_FIELD_TYPE_INDEX_TYPE, 26). %% secondary index type
-define(AS_MSG_FIELD_TYPE_UDF_FILENAME, 30). %% udf file name
-define(AS_MSG_FIELD_TYPE_UDF_FUNCTION, 31). %% udf function
-define(AS_MSG_FIELD_TYPE_UDF_ARGLIST, 32). %% udf argument list
-define(AS_MSG_FIELD_TYPE_UDF_OP, 33). %% udf operation type
-define(AS_MSG_FIELD_TYPE_QUERY_BINLIST, 40). %% bins to return on a secondary index query

%% mapping from field type ID to atom
-define(
   ft2a(FieldType),
   case FieldType of
       ?AS_MSG_FIELD_TYPE_NAMESPACE -> namespace;
       ?AS_MSG_FIELD_TYPE_SET -> set;
       ?AS_MSG_FIELD_TYPE_KEY -> key;
       ?AS_MSG_FIELD_TYPE_BIN -> bin;
       ?AS_MSG_FIELD_TYPE_DIGEST_RIPE -> digest_ripe;
       ?AS_MSG_FIELD_TYPE_GU_TID -> gu_tid;
       ?AS_MSG_FIELD_TYPE_DIGEST_RIPE_ARRAY -> digest_ripe_array;
       ?AS_MSG_FIELD_TYPE_TRID -> trid;
       ?AS_MSG_FIELD_TYPE_SCAN_OPTIONS -> scan_options;
       ?AS_MSG_FIELD_TYPE_INDEX_NAME -> index_name;
       ?AS_MSG_FIELD_TYPE_INDEX_RANGE -> index_range;
       ?AS_MSG_FIELD_TYPE_INDEX_TYPE -> index_type;
       ?AS_MSG_FIELD_TYPE_UDF_FILENAME -> udf_filename;
       ?AS_MSG_FIELD_TYPE_UDF_FUNCTION -> udf_function;
       ?AS_MSG_FIELD_TYPE_UDF_ARGLIST -> udf_arglist;
       ?AS_MSG_FIELD_TYPE_UDF_OP -> udf_op;
       ?AS_MSG_FIELD_TYPE_QUERY_BINLIST -> query_binlist
   end).

%% mapping from atom to field type ID
-define(
   a2ft(Atom),
   case Atom of
       namespace -> ?AS_MSG_FIELD_TYPE_NAMESPACE;
       set -> ?AS_MSG_FIELD_TYPE_SET;
       key -> ?AS_MSG_FIELD_TYPE_KEY;
       bin -> ?AS_MSG_FIELD_TYPE_BIN;
       digest_ripe -> ?AS_MSG_FIELD_TYPE_DIGEST_RIPE;
       gu_tid -> ?AS_MSG_FIELD_TYPE_GU_TID;
       digest_ripe_array -> ?AS_MSG_FIELD_TYPE_DIGEST_RIPE_ARRAY;
       trid -> ?AS_MSG_FIELD_TYPE_TRID;
       scan_options -> ?AS_MSG_FIELD_TYPE_SCAN_OPTIONS;
       index_name -> ?AS_MSG_FIELD_TYPE_INDEX_NAME;
       index_range -> ?AS_MSG_FIELD_TYPE_INDEX_RANGE;
       index_type -> ?AS_MSG_FIELD_TYPE_INDEX_TYPE;
       udf_filename -> ?AS_MSG_FIELD_TYPE_UDF_FILENAME;
       udf_function -> ?AS_MSG_FIELD_TYPE_UDF_FUNCTION;
       udf_arglist -> ?AS_MSG_FIELD_TYPE_UDF_ARGLIST;
       udf_op -> ?AS_MSG_FIELD_TYPE_UDF_OP;
       query_binlist -> ?AS_MSG_FIELD_TYPE_QUERY_BINLIST
   end).

%% allowed operations
-define(AS_MSG_OP_READ, 1). %% read the value in question
-define(AS_MSG_OP_WRITE, 2). %% write the value in question
-define(AS_MSG_OP_INCR, 5). %% arithmetically add a value to an existing value, works only on integers
-define(AS_MSG_OP_APPEND, 9). %% append a value to an existing value, works on strings and blobs
-define(AS_MSG_OP_PREPEND, 10). %% prepend a value to an existing value, works on strings and blobs
-define(AS_MSG_OP_TOUCH, 11). %% touch a value without doing anything else to it - will increment the generation

%% memcache-compatible operations
-define(AS_MSG_OP_MC_INCR, 129). %% Memcache-compatible version of the increment command
-define(AS_MSG_OP_MC_APPEND, 130). %% append the value to an existing value, works only strings for now
-define(AS_MSG_OP_MC_PREPEND, 131). %% prepend a value to an existing value, works only strings for now
-define(AS_MSG_OP_MC_TOUCH, 132). %% Memcache-compatible touch - does not change generation

%% mapping from operation ID to atom
-define(
   op2a(AllowedOperation),
   case AllowedOperation of
       ?AS_MSG_OP_READ -> read;
       ?AS_MSG_OP_WRITE -> write;
       ?AS_MSG_OP_INCR -> incr;
       ?AS_MSG_OP_APPEND -> append;
       ?AS_MSG_OP_PREPEND -> prepend;
       ?AS_MSG_OP_TOUCH -> touch;
       ?AS_MSG_OP_MC_INCR -> mc_incr;
       ?AS_MSG_OP_MC_APPEND -> mc_append;
       ?AS_MSG_OP_MC_PREPEND -> mc_prepend;
       ?AS_MSG_OP_MC_TOUCH -> mc_touch
   end).

%% mapping from atom to operation ID
-define(
   a2op(Atom),
   case Atom of
       read -> ?AS_MSG_OP_READ;
       write -> ?AS_MSG_OP_WRITE;
       incr -> ?AS_MSG_OP_INCR;
       append -> ?AS_MSG_OP_APPEND;
       prepend -> ?AS_MSG_OP_PREPEND;
       touch -> ?AS_MSG_OP_TOUCH;
       mc_incr -> ?AS_MSG_OP_MC_INCR;
       mc_append -> ?AS_MSG_OP_MC_APPEND;
       mc_prepend -> ?AS_MSG_OP_MC_PREPEND;
       mc_touch -> ?AS_MSG_OP_MC_TOUCH
   end).

%% bin data types
-define(AS_BIN_TYPE_NULL, 0). %% no associated content
-define(AS_BIN_TYPE_INTEGER, 1). %% a signed, 64-bit integer
-define(AS_BIN_TYPE_FLOAT, 2).
-define(AS_BIN_TYPE_STRING, 3). %% a null terminated UTF-8 string
-define(AS_BIN_TYPE_BLOB, 4). %% arbitrary length binary data
-define(AS_BIN_TYPE_TIMESTAMP, 5). %% milliseconds since 1 January 1970, 00:00:00 GMT
-define(AS_BIN_TYPE_DIGEST, 6). %% an internal Aerospike key digest
-define(AS_BIN_TYPE_JAVA_BLOB, 7).
-define(AS_BIN_TYPE_CSHARP_BLOB, 8).
-define(AS_BIN_TYPE_PYTHON_BLOB, 9).
-define(AS_BIN_TYPE_RUBY_BLOB, 10).
-define(AS_BIN_TYPE_MAX, 11).

%% mapping from bin data type IDs to atoms
-define(
   bt2a(BinDataType),
   case BinDataType of
       ?AS_BIN_TYPE_NULL -> null;
       ?AS_BIN_TYPE_INTEGER -> integer;
       ?AS_BIN_TYPE_FLOAT -> float;
       ?AS_BIN_TYPE_STRING -> string;
       ?AS_BIN_TYPE_BLOB -> blob;
       ?AS_BIN_TYPE_TIMESTAMP -> timestamp;
       ?AS_BIN_TYPE_DIGEST -> digest;
       ?AS_BIN_TYPE_JAVA_BLOB -> java_blob;
       ?AS_BIN_TYPE_CSHARP_BLOB -> csharp_blob;
       ?AS_BIN_TYPE_PYTHON_BLOB -> python_blob;
       ?AS_BIN_TYPE_RUBY_BLOB -> ruby_blob;
       ?AS_BIN_TYPE_MAX -> max
   end).

%% mapping from atoms to bin data type IDs
-define(
   a2bt(Atom),
   case Atom of
       null -> ?AS_BIN_TYPE_NULL;
       integer -> ?AS_BIN_TYPE_INTEGER;
       float -> ?AS_BIN_TYPE_FLOAT;
       string -> ?AS_BIN_TYPE_STRING;
       blob -> ?AS_BIN_TYPE_BLOB;
       timestamp -> ?AS_BIN_TYPE_TIMESTAMP;
       digest -> ?AS_BIN_TYPE_DIGEST;
       java_blob -> ?AS_BIN_TYPE_JAVA_BLOB;
       csharp_blob -> ?AS_BIN_TYPE_CSHARP_BLOB;
       python_blob -> ?AS_BIN_TYPE_PYTHON_BLOB;
       ruby_blob -> ?AS_BIN_TYPE_RUBY_BLOB;
       max -> ?AS_BIN_TYPE_MAX
   end).

%% error codes
-define(AS_PROTO_RESULT_OK, 0). %% no error
-define(AS_PROTO_RESULT_FAIL_UNKNOWN, 1). %% Unknown server error.
-define(AS_PROTO_RESULT_FAIL_NOTFOUND, 2). %% No record is found with the specified
                                           %% namespace/set/key combination. Check the correct
                                           %% namesapce/set/key is passed in.
-define(AS_PROTO_RESULT_FAIL_GENERATION, 3). %% Attempt to modify a record with unexpected
                                             %% generation. This happens on a read-modify-write
                                             %% situation where concurrent write requests collide
                                             %% and only one wins.
-define(AS_PROTO_RESULT_FAIL_PARAMETER, 4). %% Illegal parameter sent from client. Check client
                                            %% parameters and verify each is supported by current
                                            %% server version.
-define(AS_PROTO_RESULT_FAIL_RECORD_EXISTS, 5). %% For write requests which specify 'CREATE_ONLY',
                                                %% request fail because record already exists.
-define(AS_PROTO_RESULT_FAIL_BIN_EXISTS, 6). %% (future) For future write requests which specify
                                             %% 'BIN_CREATE_ONLY', request fail because any of
                                             %% the bin already exists.
-define(AS_PROTO_RESULT_FAIL_CLUSTER_KEY_MISMATCH, 7). %% On scan requests, the scan terminates
                                                       %% because cluster is in migration. Only
                                                       %% occur when client requested
                                                       %% 'fail_on_cluster_change' policy on scan.
-define(AS_PROTO_RESULT_FAIL_PARTITION_OUT_OF_SPACE, 8). %% Occurs when the stop-write is reached
                                                         %% due to memory or storage capacity.
                                                         %% Namespace no longer can accept write
                                                         %% requests.
-define(AS_PROTO_RESULT_FAIL_TIMEOUT, 9). %% Request was not completed during the allocated time,
                                          %% thus aborted.
-define(AS_PROTO_RESULT_FAIL_NO_XDR, 10). %% Write request is rejected because XDR is not
                                          %% running. Only occur when XDR configuration
                                          %% xdr-stop-writes-noxdr is on.
-define(AS_PROTO_RESULT_FAIL_UNAVAILABLE, 11). %% Server is not accepting requests. Occur during
                                               %% single node on a quick restart to join existing
                                               %% cluster.
-define(AS_PROTO_RESULT_FAIL_INCOMPATIBLE_TYPE, 12). %% Operation is not allowed due to data type
                                                     %% or namespace configuration
                                                     %% incompatibility. For example, append to
                                                     %% a float data type, or insert a non-integer
                                                     %% when namespace is configured as
                                                     %% data-in-index.
-define(AS_PROTO_RESULT_FAIL_RECORD_TOO_BIG, 13). %% Attempt to write a record whose size is
                                                  %% bigger than the configured write-block-size.
-define(AS_PROTO_RESULT_FAIL_KEY_BUSY, 14). %% Too many concurrent operations
                                            %% (> transaction-pending-limit) on the same record.
-define(AS_PROTO_RESULT_FAIL_SCAN_ABORT, 15). %% Scan aborted by user on Server.
-define(AS_PROTO_RESULT_FAIL_UNSUPPORTED_FEATURE, 16). %% This feature currently is not supported.
-define(AS_PROTO_RESULT_FAIL_BIN_NOT_FOUND, 17). %% (future) For future write requests which
                                                 %% specify 'REPLACE_ONLY', request fail because
                                                 %%  specified bin name does not exist in record.
-define(AS_PROTO_RESULT_FAIL_DEVICE_OVERLOAD, 18). %% Write request is rejected because storage
                                                   %% device is not keeping up.
-define(AS_PROTO_RESULT_FAIL_KEY_MISMATCH, 19). %% For update request on records which has key
                                                %% stored, the incoming key does not match the
                                                %% existing stored key. This indicates a
                                                %% RIPEMD160 key collision, and has never
                                                %% happened.
-define(AS_PROTO_RESULT_FAIL_NAMESPACE, 20). %% The passed in namespace does not exist on
                                             %% cluster, or no namespace parameter is passed in
                                             %% on request.
-define(AS_PROTO_RESULT_FAIL_BIN_NAME, 21). %% Bin name length greater than 14 characters, or
                                            %% maximum number of unique bin names are exceeded.
-define(AS_PROTO_RESULT_FAIL_FORBIDDEN, 22). %% Operation not allowed at this time. For writes,
                                             %% the set is in the middle of being deleted, or
                                             %% the set's stop-write is reached; For scan, too
                                             %% many concurrent scan jobs (> scan-max-active);
                                             %% For XDR-ed cluster, fail writes which are not
                                             %% replicated from another datacenter.
-define(AS_SEC_ERR_OK_LAST, 50). %% End of security response.
-define(AS_SEC_ERR_NOT_SUPPORTED, 51). %% Security functionality not supported by connected server.
-define(AS_SEC_ERR_NOT_ENABLED, 52). %% Security functionality not enabled by connected server.
-define(AS_SEC_ERR_SCHEME, 53). %% Security scheme not supported.
-define(AS_SEC_ERR_COMMAND, 54). %% Unrecognized security command.
-define(AS_SEC_ERR_FIELD, 55). %% Field is not valid.
-define(AS_SEC_ERR_STATE, 56). %% Security protocol not followed.
-define(AS_SEC_ERR_USER, 60). %% No user supplied or unknown user.
-define(AS_SEC_ERR_USER_EXISTS, 61). %% User already exists.
-define(AS_SEC_ERR_PASSWORD, 62). %% Password does not exists or not recognized.
-define(AS_SEC_ERR_EXPIRED_PASSWORD, 63). %% Expired password.
-define(AS_SEC_ERR_FORBIDDEN_PASSWORD, 64). %% Forbidden password (e.g. recently used).
-define(AS_SEC_ERR_CREDENTIAL, 65). %% Invalid credential or credential does not exist.
-define(AS_SEC_ERR_ROLE, 70). %% No role(s) or unknown role(s).
-define(AS_SEC_ERR_ROLE_EXISTS, 71). %% Role already exists.
-define(AS_SEC_ERR_PRIVILEGE, 72). %% Privilege is invalid.
-define(AS_SEC_ERR_AUTHENTICATED, 80). %% User must be authenticated before performing database
                                       %% operations.
-define(AS_SEC_ERR_ROLE_VIOLATION, 81). %% User does not possess the required role to perform
                                        %% the database operation.
-define(AS_PROTO_RESULT_FAIL_UDF_EXECUTION, 100). %% A user defined function failed to execute.
-define(AS_PROTO_RESULT_FAIL_COLLECTION_ITEM_NOT_FOUND, 125). %% The requested LDT item not found.
-define(AS_PROTO_RESULT_FAIL_BATCH_DISABLED, 150). %% Batch functionality has been disabled by
                                                   %% configuring the batch-index-thread=0.
                                                   %% Since 3.6.0
-define(AS_PROTO_RESULT_FAIL_BATCH_MAX_REQUESTS, 151). %% Batch max requests has been exceeded.
                                                       %% Since 3.6.0
-define(AS_PROTO_RESULT_FAIL_BATCH_QUEUES_FULL, 152). %% All batch queues are full.
                                                      %% Since 3.6.0
-define(AS_PROTO_RESULT_FAIL_GEO_INVALID_GEOJSON, 160). %% GeoJSON is malformed or not supported.
                                                        %% Since 3.7.0
-define(AS_PROTO_RESULT_FAIL_INDEX_FOUND, 200). %% Secondary index already exists.
-define(AS_PROTO_RESULT_FAIL_INDEX_NOT_FOUND, 201). %% Secondary index does not exist.
-define(AS_PROTO_RESULT_FAIL_INDEX_OOM, 202). %% Secondary index memory space exceeded.
-define(AS_PROTO_RESULT_FAIL_INDEX_NOTREADABLE, 203). %% Secondary index not available for query.
                                                      %% Occurs when indexing creation has not
                                                      %% finished.
-define(AS_PROTO_RESULT_FAIL_INDEX_GENERIC, 204). %% Generic secondary index error.
-define(AS_PROTO_RESULT_FAIL_INDEX_NAME_MAXLEN, 205). %% Index name maximun length exceeded.
-define(AS_PROTO_RESULT_FAIL_INDEX_MAXCOUNT, 206). %% Maximum number of indicies exceeded.
-define(AS_PROTO_RESULT_FAIL_QUERY_USERABORT, 210). %% Secondary index query aborted.
-define(AS_PROTO_RESULT_FAIL_QUERY_QUEUEFULL, 211). %% Secondary index queue full.
-define(AS_PROTO_RESULT_FAIL_QUERY_TIMEOUT, 212). %% Secondary index query timed out on server.
-define(AS_PROTO_RESULT_FAIL_QUERY_CBERROR, 213). %% Generic query error.
-define(AS_PROTO_RESULT_FAIL_QUERY_NETIO_ERR, 214). %%
-define(AS_PROTO_RESULT_FAIL_QUERY_DUPLICATE, 215). %% Internal error.

%% mapping from error code to short error description
-define(
   describeError(ErrorCode),
   case ErrorCode of
       ?AS_PROTO_RESULT_OK ->
           as_proto_result_ok;
       ?AS_PROTO_RESULT_FAIL_UNKNOWN ->
           as_proto_result_fail_unknown;
       ?AS_PROTO_RESULT_FAIL_NOTFOUND ->
           as_proto_result_fail_notfound;
       ?AS_PROTO_RESULT_FAIL_GENERATION ->
           as_proto_result_fail_generation;
       ?AS_PROTO_RESULT_FAIL_PARAMETER ->
           as_proto_result_fail_parameter;
       ?AS_PROTO_RESULT_FAIL_RECORD_EXISTS ->
           as_proto_result_fail_record_exists;
       ?AS_PROTO_RESULT_FAIL_BIN_EXISTS ->
           as_proto_result_fail_bin_exists;
       ?AS_PROTO_RESULT_FAIL_CLUSTER_KEY_MISMATCH ->
           as_proto_result_fail_cluster_key_mismatch;
       ?AS_PROTO_RESULT_FAIL_PARTITION_OUT_OF_SPACE ->
           as_proto_result_fail_partition_out_of_space;
       ?AS_PROTO_RESULT_FAIL_TIMEOUT ->
           as_proto_result_fail_timeout;
       ?AS_PROTO_RESULT_FAIL_NO_XDR ->
           as_proto_result_fail_no_xdr;
       ?AS_PROTO_RESULT_FAIL_UNAVAILABLE ->
           as_proto_result_fail_unavailable;
       ?AS_PROTO_RESULT_FAIL_INCOMPATIBLE_TYPE ->
           as_proto_result_fail_incompatible_type;
       ?AS_PROTO_RESULT_FAIL_RECORD_TOO_BIG ->
           as_proto_result_fail_record_too_big;
       ?AS_PROTO_RESULT_FAIL_KEY_BUSY ->
           as_proto_result_fail_key_busy;
       ?AS_PROTO_RESULT_FAIL_SCAN_ABORT ->
           as_proto_result_fail_scan_abort;
       ?AS_PROTO_RESULT_FAIL_UNSUPPORTED_FEATURE ->
           as_proto_result_fail_unsupported_feature;
       ?AS_PROTO_RESULT_FAIL_BIN_NOT_FOUND ->
           as_proto_result_fail_bin_not_found;
       ?AS_PROTO_RESULT_FAIL_DEVICE_OVERLOAD ->
           as_proto_result_fail_device_overload;
       ?AS_PROTO_RESULT_FAIL_KEY_MISMATCH ->
           as_proto_result_fail_key_mismatch;
       ?AS_PROTO_RESULT_FAIL_NAMESPACE ->
           as_proto_result_fail_namespace;
       ?AS_PROTO_RESULT_FAIL_BIN_NAME ->
           as_proto_result_fail_bin_name;
       ?AS_PROTO_RESULT_FAIL_FORBIDDEN ->
           as_proto_result_fail_forbidden;
       ?AS_SEC_ERR_OK_LAST ->
           as_sec_err_ok_last;
       ?AS_SEC_ERR_NOT_SUPPORTED ->
           as_sec_err_not_supported;
       ?AS_SEC_ERR_NOT_ENABLED ->
           as_sec_err_not_enabled;
       ?AS_SEC_ERR_SCHEME ->
           as_sec_err_scheme;
       ?AS_SEC_ERR_COMMAND ->
           as_sec_err_command;
       ?AS_SEC_ERR_FIELD ->
           as_sec_err_field;
       ?AS_SEC_ERR_STATE ->
           as_sec_err_state;
       ?AS_SEC_ERR_USER ->
           as_sec_err_user;
       ?AS_SEC_ERR_USER_EXISTS ->
           as_sec_err_user_exists;
       ?AS_SEC_ERR_PASSWORD ->
           as_sec_err_password;
       ?AS_SEC_ERR_EXPIRED_PASSWORD ->
           as_sec_err_expired_password;
       ?AS_SEC_ERR_FORBIDDEN_PASSWORD ->
           as_sec_err_forbidden_password;
       ?AS_SEC_ERR_CREDENTIAL ->
           as_sec_err_credential;
       ?AS_SEC_ERR_ROLE ->
           as_sec_err_role;
       ?AS_SEC_ERR_ROLE_EXISTS ->
           as_sec_err_role_exists;
       ?AS_SEC_ERR_PRIVILEGE ->
           as_sec_err_privilege;
       ?AS_SEC_ERR_AUTHENTICATED ->
           as_sec_err_authenticated;
       ?AS_SEC_ERR_ROLE_VIOLATION ->
           as_sec_err_role_violation;
       ?AS_PROTO_RESULT_FAIL_UDF_EXECUTION ->
           as_proto_result_fail_udf_execution;
       ?AS_PROTO_RESULT_FAIL_COLLECTION_ITEM_NOT_FOUND ->
           as_proto_result_fail_collection_item_not_found;
       ?AS_PROTO_RESULT_FAIL_BATCH_DISABLED ->
           as_proto_result_fail_batch_disabled;
       ?AS_PROTO_RESULT_FAIL_BATCH_MAX_REQUESTS ->
           as_proto_result_fail_batch_max_requests;
       ?AS_PROTO_RESULT_FAIL_BATCH_QUEUES_FULL ->
           as_proto_result_fail_batch_queues_full;
       ?AS_PROTO_RESULT_FAIL_GEO_INVALID_GEOJSON ->
           as_proto_result_fail_geo_invalid_geojson;
       ?AS_PROTO_RESULT_FAIL_INDEX_FOUND ->
           as_proto_result_fail_index_found;
       ?AS_PROTO_RESULT_FAIL_INDEX_NOT_FOUND ->
           as_proto_result_fail_index_not_found;
       ?AS_PROTO_RESULT_FAIL_INDEX_OOM ->
           as_proto_result_fail_index_oom;
       ?AS_PROTO_RESULT_FAIL_INDEX_NOTREADABLE ->
           as_proto_result_fail_index_notreadable;
       ?AS_PROTO_RESULT_FAIL_INDEX_GENERIC ->
           as_proto_result_fail_index_generic;
       ?AS_PROTO_RESULT_FAIL_INDEX_NAME_MAXLEN ->
           as_proto_result_fail_index_name_maxlen;
       ?AS_PROTO_RESULT_FAIL_INDEX_MAXCOUNT ->
           as_proto_result_fail_index_maxcount;
       ?AS_PROTO_RESULT_FAIL_QUERY_USERABORT ->
           as_proto_result_fail_query_userabort;
       ?AS_PROTO_RESULT_FAIL_QUERY_QUEUEFULL ->
           as_proto_result_fail_query_queuefull;
       ?AS_PROTO_RESULT_FAIL_QUERY_TIMEOUT ->
           as_proto_result_fail_query_timeout;
       ?AS_PROTO_RESULT_FAIL_QUERY_CBERROR ->
           as_proto_result_fail_query_cberror;
       ?AS_PROTO_RESULT_FAIL_QUERY_NETIO_ERR ->
           as_proto_result_fail_query_netio_err;
       ?AS_PROTO_RESULT_FAIL_QUERY_DUPLICATE ->
           as_proto_result_fail_query_duplicate;
       Other -> Other
   end).

-endif.
