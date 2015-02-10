//
//  Prototype.swift
//  Prototope
//
//  Created by Andy Matuschak on 2/9/15.
//  Copyright (c) 2015 Khan Academy. All rights reserved.
//

import Foundation
import swiftz
import swiftz_core

struct Prototype {
	var mainScript: NSData
	var images: [String: NSData]
}

extension Prototype {
	init?(url: NSURL) {
		// TODO: return a Result, kill printlns
		if !url.fileURL { return nil }

		var error: NSError? = nil
		let path = url.filePathURL!.path!

		var isDirectory: ObjCBool = ObjCBool(false)
		let exists = NSFileManager.defaultManager().fileExistsAtPath(path, isDirectory: &isDirectory)
		if !exists {
			println("File does not exist: \(path)")
			return nil
		}

		var mainScriptPath: String
		self.images = [:]
		if isDirectory.boolValue {
			var error: NSError? = nil
			let contents = NSFileManager.defaultManager().contentsOfDirectoryAtPath(path, error: &error) as [String]?
			if contents == nil {
				println("Couldn't read directory \(path): \(error)")
				return nil
			}

			let javaScriptFiles = contents!.filter { $0.pathExtension == "js" }
			switch javaScriptFiles.count {
			case 0:
				println("No JavaScript files found in \(path)")
				return nil
			case 1:
				mainScriptPath = path.stringByAppendingPathComponent(javaScriptFiles.first!)
			default:
				println("Multiple JavaScript files found in \(path): \(javaScriptFiles)")
				return nil
			}

			for imageName in contents!.filter({ $0.pathExtension == "png" }) {
				let imagePath = path.stringByAppendingPathComponent(imageName)
				if let imageData = NSData(contentsOfFile: imagePath, options: nil, error: &error) {
					self.images[imageName] = imageData
				}
			}

		} else {
			mainScriptPath = path
		}

		if let mainScriptData = NSData(contentsOfFile: mainScriptPath, options: nil, error: &error) {
			self.mainScript = mainScriptData
		} else {
			println("Failed to read main script: \(mainScriptPath): \(error)")
			return nil
		}
	}
}

extension Prototype: JSON {
	private static func create(mainScript: NSData)(images: [String: NSData]) -> Prototype { return Prototype(mainScript: mainScript, images: images) }

	static func fromJSON(jsonValue: JSONValue) -> Prototype? {
		switch jsonValue {
		case let .JSONObject(dictionary):
			return create
				<^> (dictionary["mainScript"] >>- NSDataJSONCoder.fromJSON)
				<*> (dictionary["images"] >>- JDictionaryFrom<NSData, NSDataJSONCoder>.fromJSON)
		default:
			return nil
		}
	}

	static func toJSON(prototype: Prototype) -> JSONValue {
		return .JSONObject([
			"mainScript": NSDataJSONCoder.toJSON(prototype.mainScript),
			"images": JDictionaryTo<NSData, NSDataJSONCoder>.toJSON(prototype.images)
		])
	}
}

struct NSDataJSONCoder: JSON {
	static func fromJSON(jsonValue: JSONValue) -> NSData? {
		return JString.fromJSON(jsonValue) >>- { NSData(base64EncodedString: $0, options: nil) }
	}

	static func toJSON(data: NSData) -> JSONValue {
		return JString.toJSON(data.base64EncodedStringWithOptions(nil))
	}
}