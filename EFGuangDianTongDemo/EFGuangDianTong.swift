//
//  EFGuangDianTong.swift
//  EFGuangDianTongDemo
//
//  Created by EyreFree on 16/3/25.
//  Copyright © 2016年 eyrefree. All rights reserved.
//

import Alamofire
import AdSupport

class EFGuangDianTong {

    static let sharedInstance = EFGuangDianTong()

    fileprivate var myAppid: Int!
    fileprivate var myUid: Int!
    fileprivate var mySignKey: String!
    fileprivate var myEncryptKey: String!

    fileprivate var manager: SessionManager!
    init() {
        let configuration: URLSessionConfiguration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = SessionManager.defaultHTTPHeaders
        configuration.timeoutIntervalForRequest = 30                     //超时值
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData //去缓存
        manager = SessionManager(configuration: configuration)
    }

    func Schema2(appid: Int, uid: Int, signKey: String, encryptKey: String) {
        myAppid = appid
        myUid = uid
        mySignKey = signKey
        myEncryptKey = encryptKey

        GuangDianTongSchema2()
    }

    // MARK:- API上报方案
    fileprivate func GuangDianTongSchema2() {
        if IsIDFAEnabled() {
            //参数
            if let appid = Appid(),
                let data = urlEncode(Data()),
                let convType = ConvType(),
                let appType = AppType(),
                let advertiserId = Uid() {
                //组装请求
                let attachment = "conv_type=\(convType)&app_type=\(appType)"
                    + "&advertiser_id=\(advertiserId)"
                let finalUrl = "http://t.gdt.qq.com/conv/app/\(appid)"
                    + "/conv?v=\(data)&\(attachment)"
                //请求
                manager.request(finalUrl, method: .get, parameters: nil).response() {
                    (response) in
                    if let tryData = response.data {
                        if let dict = self.dataToDictionary(tryData) as? NSDictionary {
                            if let msg = dict["msg"] as? String,
                                let ret = dict["ret"] as? Int {
                                var message = "广点通上报:"
                                switch ret {
                                case 0:
                                    message += "成功"
                                    break
                                case -1:
                                    message += "请求非法参数"
                                    break
                                case -2:
                                    message += "参数解析失败"
                                    break
                                case -3:
                                    message += "参数解码失败"
                                    break
                                case -12:
                                    message += "获取密钥失败"
                                    break
                                case -13:
                                    message += "非法的应用类型"
                                    break
                                case -14:
                                    message += "非法的转化时间"
                                    break
                                case -15:
                                    message += "非法的广点通移劢设备标识"
                                    break
                                case -17:
                                    message += "获取转化规则失败"
                                    break
                                default:
                                    break
                                }
                                NSLog(message + msg)
                            }
                        }
                    }
                }
            }
        }
    }

    fileprivate func dataToDictionary(_ data: Foundation.Data?) -> Any? {
        if let tryData = data {
            do {
                return try JSONSerialization.jsonObject(
                    with: tryData as Data, options: JSONSerialization.ReadingOptions.allowFragments
                )
            } catch {
                NSLog("dataToDictionary Error!")
            }
        }
        return nil
    }

    fileprivate func Appid() -> Int? {
        return myAppid
    }

    fileprivate func Data() -> String? {
        return VParam()
    }

    fileprivate func ConvType() -> String? {
        return "MOBILEAPP_ACTIVITE"
    }

    fileprivate func AppType() -> String? {
        return "IOS"
    }

    fileprivate func Uid() -> Int? {
        return myUid
    }

    fileprivate func SignKey() -> String {
        return mySignKey
    }

    fileprivate func EncryptKey() -> String {
        return myEncryptKey
    }

    // IDFA
    fileprivate func IsIDFAEnabled() -> Bool {
        return ASIdentifierManager.shared()
            .isAdvertisingTrackingEnabled
    }
    fileprivate func GetIDFA() -> String {
        return ASIdentifierManager.shared()
            .advertisingIdentifier.uuidString
    }

    // MARK:- V 参数加密方案
    fileprivate func VParam() -> String? {
        //组装参数
        var queryString = "muid=\(GenerateMUID())&conv_time=\(GenerateConvTime())"
        if let clientIP = GenerateClientIP() {
            queryString += "&client_ip=\(clientIP)"
        }
        if let appid = Appid() {
            //参数签名
            let page = "http://t.gdt.qq.com/conv/app/\(appid)/conv?\(queryString)"
            if let encodePage = urlEncode(page) {
                let property = "\(SignKey())&GET&\(encodePage)"
                let signature = MD5(property)
                //参数加密
                let baseData = "\(queryString)&sign=\(signature)"
                if let xorData = SimpleXor(baseData, key: EncryptKey()) {
                    return Base64(xorData)
                }
            }
        }
        return nil
    }

    // urlencode
    fileprivate func urlEncode(_ data: String?) -> String? {
        if let newData = data {
            let customAllowedSet = CharacterSet(
                charactersIn: "&:=\"#%/<>?@\\^`{|}"
                ).inverted
            return newData.addingPercentEncoding(
                withAllowedCharacters: customAllowedSet
            )
        }
        return nil
    }

    // CONV_TIME
    fileprivate func GenerateConvTime() -> String {
        return String(Int(Date().timeIntervalSince1970))
    }

    fileprivate func GenerateClientIP() -> String? {
        return nil
    }

    //简单异或
    fileprivate func SimpleXor(_ info: String, key: String) -> Foundation.Data? {
        var res = [CChar]()
        if let infoArray = info.cString(using: String.Encoding.utf8),
            let keyArray = key.cString(using: String.Encoding.utf8) {
            var j: Int = 0
            for infoEle in infoArray {
                res.append(infoEle ^ keyArray[j])
                j += 1
                j = j % (keyArray.count - 1)
            }
            return Foundation.Data(bytes: UnsafeRawPointer(res), count: res.count - 1)
        }
        return nil
    }

    //base64
    fileprivate func Base64(_ data: Foundation.Data) -> String? {
        return data.base64EncodedString(
            options: NSData.Base64EncodingOptions(rawValue: 0)
        )
    }

    //md5
    fileprivate func MD5(_ data: String,
                         length: Int32 = CC_MD5_DIGEST_LENGTH) -> String {
        let str = data.cString(using: String.Encoding.utf8)
        let strLen = CC_LONG(
            data.lengthOfBytes(using: String.Encoding.utf8)
        )
        let digestLen = Int(length)
        let result = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: digestLen)
        CC_MD5(str!, strLen, result)
        let hash = NSMutableString()
        for i in 0..<digestLen {
            hash.appendFormat("%02x", result[i])
        }
        result.deallocate(capacity: digestLen)
        return String(hash)
    }
    
    // MARK:- muid 加密方案
    fileprivate func GenerateMUID() -> String {
        return MD5(GetIDFA().uppercased())
    }
}
