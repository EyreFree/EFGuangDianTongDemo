//
//  EFGuangDianTong.swift
//  GuangDianTongDemo
//
//  Created by EyreFree on 16/3/25.
//  Copyright © 2016年 eyrefree. All rights reserved.
//

import Foundation
import Alamofire
import AdSupport

class EFGuangDianTong {

    static let sharedInstance = EFGuangDianTong()

    private var myAppid: Int!
    private var myUid: Int!
    private var mySignKey: String!
    private var myEncryptKey: String!

    private var manager: Manager!
    init() {
        let configuration: NSURLSessionConfiguration =
        NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.HTTPAdditionalHeaders = Manager.defaultHTTPHeaders
        configuration.timeoutIntervalForRequest = 30                     //超时值
        configuration.requestCachePolicy = .ReloadIgnoringLocalCacheData //去缓存
        manager = Manager(configuration: configuration)
    }

    func Schema2(appid appid: Int, uid: Int, signKey: String, encryptKey: String) {
        myAppid = appid
        myUid = uid
        mySignKey = signKey
        myEncryptKey = encryptKey

        GuangDianTongSchema2()
    }

    // MARK:- API上报方案
    private func GuangDianTongSchema2() {
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
                    manager.request(
                        .GET, finalUrl, parameters: nil, encoding: .JSON)
                        .response() {
                            (request, response, dataOri, error) in
                            if let dict = self.dataToDictionary(dataOri) as? NSDictionary {
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

    private func dataToDictionary(data: NSData?) -> AnyObject? {
        if nil == data {
            return nil
        }
        do {
            return try NSJSONSerialization.JSONObjectWithData(
                data!, options: NSJSONReadingOptions.AllowFragments
            )
        } catch {
            NSLog("dataToDictionary Error!")
            return nil
        }
    }

    private func Appid() -> Int? {
        return myAppid
    }

    private func Data() -> String? {
        return VParam()
    }

    private func ConvType() -> String? {
        return "MOBILEAPP_ACTIVITE"
    }

    private func AppType() -> String? {
        return "IOS"
    }

    private func Uid() -> Int? {
        return myUid
    }

    private func SignKey() -> String {
        return mySignKey
    }

    private func EncryptKey() -> String {
        return myEncryptKey
    }

    // IDFA
    private func IsIDFAEnabled() -> Bool {
        return ASIdentifierManager.sharedManager()
            .advertisingTrackingEnabled
    }
    private func GetIDFA() -> String {
        return ASIdentifierManager.sharedManager()
            .advertisingIdentifier.UUIDString
    }

    // MARK:- V 参数加密方案
    private func VParam() -> String? {
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
    private func urlEncode(data: String?) -> String? {
        if let newData = data {
            let customAllowedSet = NSCharacterSet(
                charactersInString: "&:=\"#%/<>?@\\^`{|}"
                ).invertedSet
            return newData.stringByAddingPercentEncodingWithAllowedCharacters(
                customAllowedSet
            )
        }
        return nil
    }

    // CONV_TIME
    private func GenerateConvTime() -> String {
        return String(Int(NSDate().timeIntervalSince1970))
    }

    private func GenerateClientIP() -> String? {
        return nil
    }

    //简单异或
    private func SimpleXor(info: String, key: String) -> NSData? {
        var res = [CChar]()
        if let infoArray = info.cStringUsingEncoding(NSUTF8StringEncoding),
            let keyArray = key.cStringUsingEncoding(NSUTF8StringEncoding) {
                var j: Int = 0
                for infoEle in infoArray {
                    res.append(infoEle ^ keyArray[j])
                    j = (++j) % (keyArray.count - 1)
                }
                return NSData(bytes: res, length: res.count - 1)
        }
        return nil
    }

    //base64
    private func Base64(data: NSData) -> String? {
        return data.base64EncodedStringWithOptions(
            NSDataBase64EncodingOptions(rawValue: 0)
        )
    }

    //md5
    private func MD5(data: String,
        length: Int32 = CC_MD5_DIGEST_LENGTH) -> String {
            let str = data.cStringUsingEncoding(NSUTF8StringEncoding)
            let strLen = CC_LONG(
                data.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
            )
            let digestLen = Int(length)
            let result = UnsafeMutablePointer<CUnsignedChar>.alloc(digestLen)
            CC_MD5(str!, strLen, result)
            let hash = NSMutableString()
            for i in 0..<digestLen {
                hash.appendFormat("%02x", result[i])
            }
            result.dealloc(digestLen)
            return String(hash)
    }

    // MARK:- muid 加密方案
    private func GenerateMUID() -> String {
        return MD5(GetIDFA().uppercaseString)
    }
}