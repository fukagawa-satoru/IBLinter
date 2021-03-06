//
//  ImageResourcesRule.swift
//  IBLinterKit
//
//  Created by SaitoYuta on 2018/05/11.
//

import Foundation
import IBDecodable
import xcproj

extension Rules {

    struct ImageResourcesRule: Rule {

        static let identifier: String = "image_resources"

        let assetsCatalogs: [AssetsCatalog]
        let xcodeproj: [XcodeProj]

        public init(context: Context) {
            let paths = glob(pattern: "\(context.workDirectory)/**/*.xcassets")
            let excluded = context.config.excluded.flatMap { glob(pattern: "\($0)/**/*.xcassets") }
            let lintablePaths = paths.filter { !excluded.map { $0.absoluteString }.contains($0.absoluteString) }
            self.init(catalogs: lintablePaths.map { AssetsCatalog.init(path: $0.relativePath) })
        }

        init(catalogs: [AssetsCatalog]) {
            self.assetsCatalogs = catalogs
            self.xcodeproj = glob(pattern: "*.xcodeproj").compactMap {
                try? XcodeProj.init(pathString: $0.path)
            }
        }

        func validate(xib: XibFile) -> [Violation] {
            return validate(
                for: xib.document.children(of: Image.self),
                imageViews: xib.document.children(of: ImageView.self),
                file: xib
            )
        }

        func validate(storyboard: StoryboardFile) -> [Violation] {
            return validate(
                for: storyboard.document.children(of: Image.self),
                imageViews: storyboard.document.children(of: ImageView.self),
                file: storyboard
            )
        }

        private func validate<T: InterfaceBuilderFile>(for images: [Image], imageViews: [ImageView], file: T) -> [Violation] {
            let imageNames = images.map { $0.name }
            let catalogAssetNames = assetsCatalogs.flatMap { $0.names }
            let xcodeprojAssetNames = xcodeproj.flatMap {
                $0.pbxproj.objects.fileReferences.compactMap {
                    $0.value.name
                }
            }
            let assetNames = catalogAssetNames + xcodeprojAssetNames
            return imageViews.filter { !(imageNames.contains($0.image) && assetNames.contains($0.image)) }
                .map {
                    Violation(
                        pathString: file.pathString,
                        message: "\($0.image) not found",
                        level: .error)
            }
        }
    }
}

private extension AssetsCatalog {
    var names: [String] {
        return entries.flatMap { $0.names }
    }
}

private extension AssetsCatalog.Entry {
    var names: [String] {
        switch self {
        case .group(_, let items):
            return items.flatMap { $0.names }
        case .color(let name, _):
            return [name]
        case .image(let name, _):
            return [name]
        }
    }
}
