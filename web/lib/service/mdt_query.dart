import 'package:angular/angular.dart';
import 'dart:async';
import "dart:html";
import 'dart:convert';
import '../model/errors.dart';
import '../model/mdt_model.dart';

final String mdtServerApiRootUrl = "http://localhost:8080/api";
final String appVersion = "v1";
final String appPath = "/applications/${appVersion}";
final String artifactsPath = "/art/${appVersion}";
final String usersPath = "/users/${appVersion}";

@Injectable()
class MDTQueryService {
  Http _http;
  var lastAuthorizationHeader = '';

  void setHttpService(Http http) {
    this._http = http;
  }

  MDTQueryService() {
    print("MDTQueryService constructor");
  }

  Map allHeaders({String contentType}) {
    var requestContentType =
        contentType != null ? contentType : 'application/json; charset=utf-8';
    var initialHeaders = {
      "content-type": requestContentType,
      "accept": 'application/json' /*,"Access-Control-Allow-Headers":"*"*/
    };
    if (lastAuthorizationHeader.length > 0) {
      initialHeaders['authorization'] = lastAuthorizationHeader;
    } else {
      initialHeaders.remove('authorization');
    }
    return initialHeaders;
  }

  void checkAuthorizationHeader(HttpResponse response) async {
    if (response.status == 401) {
      lastAuthorizationHeader = '';
      throw new LoginError();
    }

    var newHeader = response.headers('authorization');
    print("auth Header $newHeader");
    if (newHeader != null) {
      lastAuthorizationHeader = newHeader;
    }
  }

  Map parseResponse(HttpResponse response) {
    checkAuthorizationHeader(response);

    var responseData = response.data;
    if (response.data is Map) {
      return responseData;
    }
    return JSON.decode(response.data);
  }

  HttpResponse sendRequest(String method, String url,
      {String query, String body, String contentType}) async {
    //var url = '$baseUrlHost$path';
    Http http = this._http;
    if (query != null) {
      url = '$url$query';
    }
    var headers = contentType == null
        ? allHeaders()
        : allHeaders(contentType: contentType);
    var httpBody = body;
    if (body == null) {
      httpBody = '';
    }
    try {
      switch (method) {
        case 'GET':
          return await http.get(url,
              headers: allHeaders(contentType: contentType));
        case 'POST':
          return await http.post(url, httpBody, headers: headers);
        case 'PUT':
          return await http.put(url, httpBody, headers: headers);
        case 'DELETE':
          return await http.delete(url, headers: headers);
      }
    } catch (e) {
      print("error $e");
      return e;
    }
    return null;
  }

  Map registerUser(String username, String email, String password) async {
    String url = "${mdtServerApiRootUrl}${usersPath}/register";
    var userRegistration = {
      "email": "$email",
      "password": "$password",
      "name": "$username"
    };
    var response =
        await sendRequest('POST', url, body: JSON.encode(userRegistration));
    var responseJson = parseResponse(response);

    if (responseJson["error"] != null) {
      throw new RegisterError(responseJson["error"]["message"]);
    }
    return responseJson;
  }

  Future<Map> loginUser(String email, String password) async {
    String url = '${mdtServerApiRootUrl}${usersPath}/login';
    var userLogin = {"email": "$email", "password": "$password"};
    var response = await sendRequest('POST', url,
        body: 'username=${email}&password=${password}',
        contentType: 'application/x-www-form-urlencoded');
    var responseJson = parseResponse(response);

    return responseJson;
  }

  MDTApplication createApplication(
      String name, String description, String platform, String icon) async {
    var appData = {
      "name": name,
      "description": description,
      "platform": platform
    };
    var response = await sendRequest(
        'POST', '${mdtServerApiRootUrl}${appPath}/create',
        body: JSON.encode(appData));
    var responseJson = parseResponse(response);

    if (responseJson["error"] != null) {
      throw new ApplicationError(responseJson["error"]["message"]);
    }

    return new MDTApplication(responseJson["data"]);
  }

  MDTApplication updateApplication(
      String appId, String name, String description, String icon) async {
    var appData = {"name": name, "description": description};
    var response = await sendRequest(
        'PUT', '${mdtServerApiRootUrl}${appPath}/app/$appId',
        body: JSON.encode(appData));
    var responseJson = parseResponse(response);

    if (responseJson["error"] != null) {
      throw new ApplicationError(responseJson["error"]["message"]);
    }

    return new MDTApplication(responseJson["data"]);
  }

  MDTApplication getApplication(String appId) async {
    var url = '${mdtServerApiRootUrl}${appPath}/app/$appId';

    var response = await sendRequest('GET', url);
    var responseJson = parseResponse(response);

    if (responseJson["error"] != null) {
      throw new ApplicationError(responseJson["error"]["message"]);
    }
    var appFound = responseJson["data"];
    if (appFound != null) {
      return new MDTApplication(appFound);
    }

    throw new ApplicationError("Unable to parse response ${responseJson}");
  }

  List<MDTApplication> getApplications({String platformFilter}) async {
    var url = '${mdtServerApiRootUrl}${appPath}/search';
    if (platformFilter != null) {
      url += 'platform=$platformFilter';
    }
    var response = await sendRequest('GET', url);
    var responseJson = parseResponse(response);

    var foundAppList = new List<MDTApplication>();
    var appList = responseJson["list"];
    if (appList != null) {
      for (Map app in appList) {
        foundAppList.add(new MDTApplication(app));
      }
    }

    return foundAppList;
  }

  bool deleteApplication(MDTApplication appToDelete) async {}

  MDTArtifact addArtifact(String apiKey, File file, String name,
      {bool latest,
      String branch,
      String version,
      String jsonTags,
      String sortIdentifier}) async {
    if ((apiKey == null) || (file == null) || (name == null)) {
      throw new ArtifactsError("Bad parameters");
    }
    var url = '${mdtServerApiRootUrl}${artifactsPath}/artifacts/${apiKey}';
    if (latest) {
      url = '$url/last/$name';
    } else {
      if ((branch == null) || (version == null)) {
        throw new ArtifactsError("Bad parameters");
      }
      url = '$url/$branch/$version/$name';
    }

    var formData = new FormData();
    formData.appendBlob("artifactFile", file);
    if (sortIdentifier != null) {
      formData.append("sortIdentifier", sortIdentifier);
    }

    if (jsonTags != null) {
      formData.append("jsonTags", jsonTags);
    }
    var response = await HttpRequest.request(url, method: "POST", sendData: formData);
  }
/*

    var url = '${mdtServerApiRootUrl}${artifactsPath}/artifacts/${apiKey}/master/versionBeta/prodArtifact'
    var httprequest = new http.MultipartRequest('POST',Uri.parse("${baseUrlHost}/api/art/v1/artifacts/${apiKey}/master/versionBeta/prodArtifact"));
    var filePart = await http.MultipartFile.fromPath('artifactFile', Directory.current.path+'/test/core/artifact_sample.txt');
    httprequest.files.add(filePart);
    httprequest.fields['sortIdentifier'] = 'sortId';
    var tags = new Map();
    tags['tag1'] = "test tag1";
    tags['tag2'] = "test tag2";
    httprequest.fields['jsonTags'] = JSON.encode(tags);

    var response = await http.Response.fromStream(await httprequest.send());

    ApiMethod(method: 'POST', path: 'artifacts/{apiKey}/last/{artifactName}')
  }

  bool deleteArtifact(String artifactId) async{
  */

}