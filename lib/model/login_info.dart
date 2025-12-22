class LoginInfo {
  String? appId = "";
  String? appName = "";
  String? empId = "";
  String? password = "";
  String? empName = "";
  int? groupId = 0;
  String? groupName = "";
  String? verChkRet = "";
  String? retMsg = "";

  LoginInfo({
    this.appId,
    this.appName,
    this.empId,
    this.password,
    this.empName,
    this.groupId,
    this.groupName,
    this.verChkRet,
    this.retMsg,
  });

  LoginInfo.fromJson(Map<String, dynamic> json) {
    appId = json['AppId'];
    appName = json['AppName'];
    empId = json['EmpId'];
    password = json['Password'];
    empName = json['EmpName'];
    groupId = json['GroupId'];
    groupName = json['GroupName'];
    verChkRet = json['VerChkRet'];
    retMsg = json['RetMsg'];
  }
}