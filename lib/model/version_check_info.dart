class VersionCheckInfoResponse {
  String resultCode = "";
  String resultMessage = "";
  VersionInfo? versionInfo;

  VersionCheckInfoResponse({
    required this.resultCode,
    required this.resultMessage,
    this.versionInfo,
  });

  VersionCheckInfoResponse.fromJson(Map<String, dynamic> json) {
    resultCode = json['ResultCode'];
    resultMessage = json['ResultMessage'];
  }

  Map<String, dynamic> toJson() => {
    "ResultCode": resultCode,
    "ResultMessage": resultMessage,
    "VersionInfo": versionInfo,
  };

}


class VersionInfo {
  String appName = "";
  int majorVer = 0;
  int minorVer = 0;
  int patchVer = 0;
  String lastAppVer = "";
  String installUrl = "";
  String fileName = "";
  String verChkRet = "";
  String retMsg = "";

  VersionInfo({
    required this.appName,
    required this.majorVer,
    required this.minorVer,
    required this.patchVer,
    required this.lastAppVer,
    required this.installUrl,
    required this.fileName,
    required this.verChkRet,
    required this.retMsg,
  });

  VersionInfo.fromJson(Map<String, dynamic> json) {
    appName = json['AppName'];
    majorVer = json['MajorVer'];
    minorVer = json['MinorVer'];
    patchVer = json['PatchVer'];
    lastAppVer = json['LastAppVer'];
    installUrl = json['InstallUrl'];
    fileName = json['FileName'];
    verChkRet = json['VerChkRet'];
    retMsg = json['RetMsg'];
  }

  Map<String, dynamic> toJson() => {
    "AppName": appName,
    "MajorVer": majorVer,
    "MinorVer": minorVer,
    "PatchVer": patchVer,
    "LastAppVer": lastAppVer,
    "InstallUrl": installUrl,
    "FileName": fileName,
    "VerChkRet": verChkRet,
    "RegMsg": retMsg,
  };

}