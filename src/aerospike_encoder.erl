%%% @doc
%%% Aerospike message encoder.

%%% @author Aleksey Morarash <aleksey.morarash@gmail.com>
%%% @since 02 May 2016
%%% @copyright 2016, Aleksey Morarash <aleksey.morarash@gmail.com>

-module(aerospike_encoder).

%% API exports
-export([encode/3]).

-include("aerospike.hrl").
-include("aerospike_defaults.hrl").
-include("aerospike_constants.hrl").

%% ----------------------------------------------------------------------
%% API functions
%% ----------------------------------------------------------------------

%% @doc
-spec encode(Fields :: list(), Ops :: list(),
             Options :: aerospike_socket:msg_options()) ->
                    binary().
encode(Fields, Ops, Options) ->
    Info1 = encode_flags(Options, ?info1weights),
    Info2 = encode_flags(Options, ?info2weights),
    Info3 = encode_flags(Options, ?info3weights),
    Generation = proplists:get_value(generation, Options, 0),
    RecordTTL = proplists:get_value(record_ttl, Options, 0),
    TransactionTTL = proplists:get_value(transaction_ttl, Options, 0),
    Nfields = length(Fields),
    Nops = length(Ops),
    Headers =
        <<Info1/binary,
          Info2/binary,
          Info3/binary,
          (_Unused = 0):8,
          (_ResultCode = 0):8,
          Generation:32/big-unsigned,
          RecordTTL:32/big-signed,
          TransactionTTL:32/big-unsigned,
          Nfields:16/big-unsigned,
          Nops:16/big-unsigned>>,
    EncodedFields = iolist_to_binary([encode_field(T, V) || {T, V} <- Fields]),
    EncodedOps =
        iolist_to_binary(
          [encode_op(O, T, N, D) || {O, T, N, D} <- Ops]),
    Request =
        <<(size(Headers) + 1):8, Headers/binary,
          EncodedFields/binary, EncodedOps/binary>>,
    MsgSize = size(Request),
    <<?VERSION:8, ?AerospikeMessage:8, MsgSize:48/big-unsigned, Request/binary>>.

%% ----------------------------------------------------------------------
%% Internal functions
%% ----------------------------------------------------------------------

%% @doc Encode info{1,2,3} flag set.
%% Helper for the msg/5 API call.
-spec encode_flags(Flags :: [atom()], Spec :: [{atom(), Weight :: pos_integer()}]) ->
                          binary().
encode_flags(Flags, Spec) ->
    Packed =
        lists:foldl(
          fun({Flag, Weight}, Accum) ->
                  case lists:member(Flag, Flags) of
                      true ->
                          Accum + Weight;
                      false ->
                          Accum
                  end
          end, 0, Spec),
    <<Packed:8/big-unsigned>>.

%% @doc Helper for the msg/5 API function.
-spec encode_field(FieldType :: integer() | atom(), FieldValue :: binary()) ->
                          binary().
encode_field(FieldType0, FieldValue) ->
    FieldType =
        if is_atom(FieldType0) ->
                ?a2ft(FieldType0);
           true ->
                FieldType0
        end,
    Length = size(FieldValue) + 1,
    <<Length:32/big-unsigned, FieldType:8/unsigned, FieldValue/binary>>.

%% @doc Helper for the msg/5 API function.
-spec encode_op(Operation :: integer() | atom(),
                BinDataType :: integer() | atom(),
                BinName :: binary(),
                BinData :: any()) ->
                       binary().
encode_op(Operation0, BinDataType0, BinName, BinData) ->
    Operation =
        if is_atom(Operation0) ->
                ?a2op(Operation0);
           true ->
                Operation0
        end,
    BinDataType =
        if is_atom(BinDataType0) ->
                ?a2bt(BinDataType0);
           true ->
                BinDataType0
        end,
    BinNameLen = size(BinName),
    EncodedBinData = encode_bin_data(BinDataType, BinData),
    Size = 4 + BinNameLen + size(EncodedBinData),
    <<Size:32/big-unsigned, Operation:8/unsigned, BinDataType:8/unsigned,
      (_BinVersion__UNUSED = 0):8/unsigned,
      BinNameLen:8/unsigned, BinName/binary, EncodedBinData/binary>>.

%% @doc
-spec encode_bin_data(BinDataType :: integer(), BinData :: any()) ->
                             binary().
encode_bin_data(?AS_BIN_TYPE_INTEGER, Integer) when is_integer(Integer) ->
    <<Integer:64/big-unsigned>>;
encode_bin_data(?AS_BIN_TYPE_FLOAT, Float) when is_float(Float) ->
    <<Float/float>>;
encode_bin_data(_BinDataType, Binary) when is_binary(Binary) ->
    %% already encoded
    Binary.
