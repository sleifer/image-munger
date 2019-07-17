## image-munger (imp) documentation

An image processing swiss army knife that can be driven by manifest files describing how to process images. Meant primarily for generating assets for Xcode projects.

### manifest files

Manifest files can contain one or more process descriptions.

They contain:

- Comments: lines starting with "#"
- Process separator: lines starting with "--"
- Settings: <key> = <value> lines
- Ordered list of source files: Any non-blank lines that are not comments, process separators, or settings.

Paths in the manifest file can be:

- absolute
- relative to imp execution directory
- relative to output directory if they start with "~~~/"
- relative to directory containing manifest file if they start with "~~/"

Manifests can contain the following keys:

- src: the source directory, or file if there is only one file
- src-oval: the source directory, or file if there is only one file - for iconSet(s) when you want different source images for the oval vs square set members
- src-square: the source directory, or file if there is only one file - for iconSet(s) when you want different source images for the oval vs square set members
- dst: the output directory
- preset: the process preset to use
- valid-format:
- out-manifest: path to write a json manifest of output images
- out-format: specify a specific image format for the output
- out-package: the package type for the output
- out-package-replace: (true | false) whether to fully replace an existing package contents when processing
- scale: factor to scale image by
- max-px: square box size to fix image in
- max-width-px: width of box to fit image in
- max-height-px: height of box to fit image in

### Defined Presets

- none: defines no actions

- smallSticker: generates small stickers for messages (100x100 @3x -> 300x300 box)
- mediumSticker: generates medium stickers for messages (136x136 @3x -> 408x408 box)
- largeSticker: generates large stickers for messages (206x206 @3x -> 618x618 box)
- thumb256: generates tumbnails in a 256x256 box
- imageSet: generates images at 1, 2, and 3x given the 3x image (an imageSet)
- stickerImageSet1: generate an imageSet with the 3x the same size as a large sticker (618x618 box) - 1x is actual image, 2x, and 3x are 1x1 pixel filler
- stickerImageSet2: generate an imageSet with the 3x the same size as a large sticker (618x618 box) - 2x is actual image, 1x, and 3x are 1x1 pixel filler
- stickerImageSet3: generate an imageSet with the 3x the same size as a large sticker (618x618 box) - 3x is actual image, 1x, and 2x are 1x1 pixel filler
- stickerImageSet12: generate an imageSet with the 3x the same size as a large sticker (618x618 box) - 1x, and 2x are actual image, 3x is 1x1 pixel filler
- stickerImageSet13: generate an imageSet with the 3x the same size as a large sticker (618x618 box) - 1x, and 3x are actual image, 2x is 1x1 pixel filler
- stickerImageSet23: generate an imageSet with the 3x the same size as a large sticker (618x618 box) - 2x, and 3x are actual image, 1x is 1x1 pixel filler
- stickerImageSet123: generate an imageSet with the 3x the same size as a large sticker (618x618 box) - 1x, 2x, and 3x are actual image
- stickerImageFiles1: generate imageSet style files with the 3x the same size as a large sticker (618x618 box) - only 1x
- stickerImageFiles2: generate imageSet style files with the 3x the same size as a large sticker (618x618 box) - only 2x
- stickerImageFiles3: generate imageSet style files with the 3x the same size as a large sticker (618x618 box) - only 3x
- stickerImageFiles12: generate imageSet style files with the 3x the same size as a large sticker (618x618 box) - only 1x, 2x
- stickerImageFiles13: generate imageSet style files with the 3x the same size as a large sticker (618x618 box) - only 1x,3x
- stickerImageFiles23: generate imageSet style files with the 3x the same size as a large sticker (618x618 box) - only 2x, 3x
- stickerImageFiles123: generate imageSet style files with the 3x the same size as a large sticker (618x618 box) - 1x, 2x, 3x

### Image Formats

- unchanged
- JPEG
- PNG
- GIF
- TIFF

### Package Types

- none
- stickerpack
- imageset
- iconset
- icns
- catalog

Publishing in 2021 so I can share a few tools.

Released under the MIT License.
