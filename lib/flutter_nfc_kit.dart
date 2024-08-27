import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ndef/ndef.dart' as ndef;
import 'package:ndef/ndef.dart' show TypeNameFormat;
import 'package:ndef/utilities.dart';
import 'package:json_annotation/json_annotation.dart';

part 'flutter_nfc_kit.g.dart';

enum NFCAvailability {
  not_supported,
  disabled,
  available,
}

enum NFCTagType {
  iso7816,
  iso15693,
  iso18092,
  mifare_classic,
  mifare_ultralight,
  mifare_desfire,
  mifare_plus,
  webusb,
  unknown,
}

@JsonSerializable()
class MifareInfo {
  final String type;
  final int size;
  final int blockSize;
  final int blockCount;
  final int? sectorCount;

  MifareInfo(
      this.type, this.size, this.blockSize, this.blockCount, this.sectorCount);

  factory MifareInfo.fromJson(Map<String, dynamic> json) =>
      _$MifareInfoFromJson(json);

  Map<String, dynamic> toJson() => _$MifareInfoToJson(this);
}

@JsonSerializable()
class NFCTag {
  final NFCTagType type;
  final String standard;
  final String id;
  final String? atqa;
  final String? sak;
  final String? historicalBytes;
  final String? hiLayerResponse;
  final String? protocolInfo;
  final String? applicationData;
  final String? manufacturer;
  final String? systemCode;
  final String? dsfId;
  final bool? ndefAvailable;
  final String? ndefType;
  final int? ndefCapacity;
  final bool? ndefWritable;
  final bool? ndefCanMakeReadOnly;
  final String? webUSBCustomProbeData;
  final MifareInfo? mifareInfo;

  NFCTag(
      this.type,
      this.id,
      this.standard,
      this.atqa,
      this.sak,
      this.historicalBytes,
      this.protocolInfo,
      this.applicationData,
      this.hiLayerResponse,
      this.manufacturer,
      this.systemCode,
      this.dsfId,
      this.ndefAvailable,
      this.ndefType,
      this.ndefCapacity,
      this.ndefWritable,
      this.ndefCanMakeReadOnly,
      this.webUSBCustomProbeData,
      this.mifareInfo);

  factory NFCTag.fromJson(Map<String, dynamic> json) => _$NFCTagFromJson(json);

  Map<String, dynamic> toJson() => _$NFCTagToJson(this);
}

@JsonSerializable()
class NDEFRawRecord {
  final String identifier;
  final String payload;
  final String type;
  final TypeNameFormat typeNameFormat;

  NDEFRawRecord(this.identifier, this.payload, this.type, this.typeNameFormat);

  factory NDEFRawRecord.fromJson(Map<String, dynamic> json) =>
      _$NDEFRawRecordFromJson(json);

  Map<String, dynamic> toJson() => _$NDEFRawRecordToJson(this);
}

extension NDEFRecordConvert on ndef.NDEFRecord {
  NDEFRawRecord toRaw() {
    return NDEFRawRecord(id?.toHexString() ?? '', payload?.toHexString() ?? '',
        type?.toHexString() ?? '', tnf);
  }

  static ndef.NDEFRecord fromRaw(NDEFRawRecord raw) {
    return ndef.decodePartialNdefMessage(
        raw.typeNameFormat, raw.type.toBytes(), raw.payload.toBytes(),
        id: raw.identifier == "" ? null : raw.identifier.toBytes());
  }
}

class Iso15693RequestFlags {
  bool dualSubCarriers;
  bool highDataRate;
  bool inventory;
  bool protocolExtension;
  bool select;
  bool address;
  bool option;
  bool commandSpecificBit8;

  int encode() {
    var result = 0;
    if (dualSubCarriers) result |= 0x01;
    if (highDataRate) result |= 0x02;
    if (inventory) result |= 0x04;
    if (protocolExtension) result |= 0x08;
    if (select) result |= 0x10;
    if (address) result |= 0x20;
    if (option) result |= 0x40;
    if (commandSpecificBit8) result |= 0x80;
    return result;
  }

  Iso15693RequestFlags(
      {this.dualSubCarriers = false,
      this.highDataRate = false,
      this.inventory = false,
      this.protocolExtension = false,
      this.select = false,
      this.address = false,
      this.option = false,
      this.commandSpecificBit8 = false});

  factory Iso15693RequestFlags.fromRaw(int r) {
    assert(r >= 0 && r <= 0xFF, "raw flags must be in range [0, 255]");
    return Iso15693RequestFlags(
        dualSubCarriers: (r & 0x01) != 0,
        highDataRate: (r & 0x02) != 0,
        inventory: (r & 0x04) != 0,
        protocolExtension: (r & 0x08) != 0,
        select: (r & 0x10) != 0,
        address: (r & 0x20) != 0,
        option: (r & 0x40) != 0,
        commandSpecificBit8: (r & 0x80) != 0);
  }
}

class FlutterNfcKit {
  static const int TRANSCEIVE_TIMEOUT = 5 * 1000;
  static const int POLL_TIMEOUT = 20 * 1000;
  static const MethodChannel _channel = MethodChannel('flutter_nfc_kit');

  static Future<NFCAvailability> get nfcAvailability async {
    final String availability =
        await _channel.invokeMethod('getNFCAvailability');
    return NFCAvailability.values
        .firstWhere((it) => it.toString() == "NFCAvailability.$availability");
  }

  static Future<NFCTag> poll({
    Duration? timeout,
    bool androidPlatformSound = true,
    bool androidCheckNDEF = true,
    String iosAlertMessage = "Hold your iPhone near the card",
    String iosMultipleTagMessage =
        "More than one tags are detected, please leave only one tag and try again.",
    bool readIso14443A = true,
    bool readIso14443B = true,
    bool readIso18092 = true,
    bool readIso15693 = true,
    bool probeWebUSBMagic = false,
  }) async {
    int technologies = 0x0;
    if (readIso14443A) technologies |= 0x1;
    if (readIso14443B) technologies |= 0x2;
    if (readIso18092) technologies |= 0x4;
    if (readIso15693) technologies |= 0x8;
    if (!androidCheckNDEF) technologies |= 0x80;
    if (!androidPlatformSound) technologies |= 0x100;
    final String data = await _channel.invokeMethod('poll', {
      'timeout': timeout?.inMilliseconds ?? POLL_TIMEOUT,
      'iosAlertMessage': iosAlertMessage,
      'iosMultipleTagMessage': iosMultipleTagMessage,
      'technologies': technologies,
      'probeWebUSBMagic': probeWebUSBMagic,
    });
    return NFCTag.fromJson(jsonDecode(data));
  }

  static Future<void> iosRestartPolling() async =>
      await _channel.invokeMethod("restartPolling");

  static Future<T> transceive<T>(T capdu, {Duration? timeout}) async {
    assert(capdu is String || capdu is Uint8List);
    return await _channel.invokeMethod('transceive', {
      'data': capdu,
      'timeout': timeout?.inMilliseconds ?? TRANSCEIVE_TIMEOUT
    });
  }

  static Future<List<ndef.NDEFRecord>> readNDEFRecords({bool? cached}) async {
    return (await readNDEFRawRecords(cached: cached))
        .map((r) => NDEFRecordConvert.fromRaw(r))
        .toList();
  }

  static Future<List<NDEFRawRecord>> readNDEFRawRecords({bool? cached}) async {
    final String data =
        await _channel.invokeMethod('readNDEF', {'cached': cached ?? false});
    return (jsonDecode(data) as List<dynamic>)
        .map((object) => NDEFRawRecord.fromJson(object))
        .toList();
  }

  static Future<void> writeNDEFRecords(List<ndef.NDEFRecord> message) async {
    return await writeNDEFRawRecords(message.map((r) => r.toRaw()).toList());
  }

  static Future<void> writeNDEFRawRecords(List<NDEFRawRecord> message) async {
    var data = jsonEncode(message);
    return await _channel.invokeMethod('writeNDEF', {'data': data});
  }

  static Future<void> finish(
      {String? iosAlertMessage,
      String? iosErrorMessage,
      bool? closeWebUSB}) async {
    return await _channel.invokeMethod('finish', {
      'iosErrorMessage': iosErrorMessage,
      'iosAlertMessage': iosAlertMessage,
      'closeWebUSB': closeWebUSB ?? false,
    });
  }

  static Future<void> setIosAlertMessage(String message) async {
    if (!kIsWeb && Platform.isIOS) {
      return await _channel.invokeMethod('setIosAlertMessage', message);
    }
  }

  static Future<void> makeNdefReadOnly() async {
    return await _channel.invokeMethod('makeNdefReadOnly');
  }

  static Future<bool> authenticateSector<T>(int index,
      {T? keyA, T? keyB}) async {
    assert((keyA.runtimeType == String || keyA.runtimeType == Uint8List) ||
        (keyB.runtimeType == String || keyB.runtimeType == Uint8List));
    return await _channel.invokeMethod(
        'authenticateSector', {'index': index, 'keyA': keyA, 'keyB': keyB});
  }

  static Future<Uint8List> readBlock(int index,
      {Iso15693RequestFlags? iso15693Flags,
      bool iso15693ExtendedMode = false}) async {
    var flags = iso15693Flags ?? Iso15693RequestFlags();
    return await _channel.invokeMethod('readBlock', {
      'index': index,
      'iso15693Flags': flags.encode(),
      'iso15693ExtendedMode': iso15693ExtendedMode,
    });
  }

  static Future<void> writeBlock<T>(int index, T data,
      {Iso15693RequestFlags? iso15693Flags,
      bool iso15693ExtendedMode = false}) async {
    assert(data is String || data is Uint8List);
    var flags = iso15693Flags ?? Iso15693RequestFlags();
    await _channel.invokeMethod('writeBlock', {
      'index': index,
      'data': data,
      'iso15693Flags': flags.encode(),
      'iso15693ExtendedMode': iso15693ExtendedMode,
    });
  }

  static Future<Uint8List> readSector(int index) async {
    return await _channel.invokeMethod('readSector', {'index': index});
  }

  static Future<bool> isConnected() async {
    return await _channel.invokeMethod('isConnected');
  }

  static Future<void> startP2P() async {
    await _channel.invokeMethod('startP2P');
  }

  static Future<void> sendP2PMessage(String message) async {
    await _channel.invokeMethod('sendP2PMessage', {'message': message});
  }

  static Future<void> stopP2P() async {
    await _channel.invokeMethod('stopP2P');
  }
}
