Existing Go source for reference

// imgx
package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"image"
	"image/color"
	"io/ioutil"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"droolingcat.com/fileutil"
	"droolingcat.com/shellutil"
	"droolingcat.com/stringutil"

	"gopkg.in/alecthomas/kingpin.v2"
	"gopkg.in/disintegration/imaging.v1"
)

var (
	app                   = kingpin.New("imgx", "A command-line image processing application.")
	srcFlag               = app.Flag("src", "Directory with source images.").ExistingFileOrDir()
	dstFlag               = app.Flag("dst", "Directory for output.").ExistingDir()
	manifestFlag          = app.Flag("manifest", "Manifest file specifying a subset of files.").ExistingFile()
	presetFlag            = app.Flag("preset", "A preset process.").Enum("smallSticker", "mediumSticker", "largeSticker", "thumb256", "imageSet")
	validTypesFlag        = app.Flag("valid-format", "Valid source image types.").Enums("jpg", "png", "gif", "tif")
	outTypeFlag           = app.Flag("out-format", "Output image type.").Enum("jpg", "png", "tif")
	scaleFlag             = app.Flag("scale", "Factor to scale image by.").Float()
	maxPxFlag             = app.Flag("max-px", "Maximum dimension in pixels.").Int()
	maxWidthPxFlag        = app.Flag("max-width-px", "Maximum width in pixels.").Int()
	maxHeightPxFlag       = app.Flag("max-height-px", "Maximum height in pixels.").Int()
	outPackageFlag        = app.Flag("out-package", "Output packaging format.").Enum("stickerpack", "imageset", "iconset")
	outPackageReplaceFlag = app.Flag("out-package-replace", "Replace existing assets in output package.").Bool()
)

type PackageType int

const (
	packageNone = iota
	packageStickerPack
	packageImageSet
	packageIconSet
	packageIcns
	packageCatalog
)

type PresetType int

const (
	presetNone PresetType = iota
	presetSmallSticker
	presetMediumSticker
	presetLargeSticker
	presetThumb256
	presetImageSet
	presetImageSetForLargeSticker
	presetLargeStickerWithImageSet
)

type ImageFormat int

const (
	formatUnchanged ImageFormat = iota
	formatJPEG
	formatPNG
	formatGIF
	formatTIFF
)

type Configuration struct {
	valid                bool
	err                  error
	srcDirPath           string
	dstDirPath           string
	manifestPath         string
	preset               PresetType
	validExtensions      []string
	outManifest          string
	outputFormat         ImageFormat
	outputPackage        PackageType
	outputPackageReplace bool
	scale                float64
	maxWidth             int
	maxHeight            int
}

type ProcessPlan struct {
	scale          float64
	boxWidth       int
	boxHeight      int
	outputFormat   ImageFormat
	outputPackage  PackageType
	requiredSuffix string
	removeSuffix   string
	addSuffix      string
}

type ProcessResult struct {
	inPath  string
	outPath string
	failed  bool
	err     error
}

type Manifest struct {
	files    []string
	settings []ManifestSetting
}

type ManifestSetting struct {
	key    string
	values []string
}

type StickerpackContents struct {
	Stickers   []StickerpackContentsSticker  `json:"stickers"`
	Info       StickerpackContentsInfo       `json:"info"`
	Properties StickerpackContentsProperties `json:"properties"`
}

type StickerpackContentsSticker struct {
	Filename string `json:"filename"`
}

type StickerpackContentsInfo struct {
	Version int32  `json:"version"`
	Author  string `json:"author"`
}

type StickerpackContentsProperties struct {
	GridSize string `json:"grid-size"`
}

type StickerContents struct {
	Info       StickerContentsInfo       `json:"info"`
	Properties StickerContentsProperties `json:"properties"`
}

type StickerContentsInfo struct {
	Version int32  `json:"version"`
	Author  string `json:"author"`
}

type StickerContentsProperties struct {
	Filename string `json:"filename"`
}

type ImagesetContents struct {
	Images []ImagesetContentsImage `json:"images"`
	Info   ImagesetContentsInfo    `json:"info"`
}

type ImagesetContentsImage struct {
	Filename string `json:"filename,omitempty"`
	Idiom    string `json:"idiom,omitempty"`
	Scale    string `json:"scale,omitempty"`
	Platform string `json:"platform,omitempty"`
	Size     string `json:"size,omitempty"`
}

type ImagesetContentsInfo struct {
	Version int32  `json:"version"`
	Author  string `json:"author"`
}

type CatalogContents struct {
	Info CatalogContentsInfo `json:"info"`
}

type CatalogContentsInfo struct {
	Version int32  `json:"version"`
	Author  string `json:"author"`
}

func readCatalogContents(path string) (CatalogContents, error) {
	var contents CatalogContents
	dat, err := ioutil.ReadFile(path)
	if err == nil {
		err = json.Unmarshal(dat, &contents)
	}
	return contents, err
}

func writeCatalogContents(path string, contents CatalogContents) error {
	contentsJson, err := json.MarshalIndent(contents, "", "  ")
	if err == nil {
		err = ioutil.WriteFile(path, contentsJson, 0644)
	}
	return err
}

func readStickerpackContents(path string) (StickerpackContents, error) {
	var contents StickerpackContents
	dat, err := ioutil.ReadFile(path)
	if err == nil {
		err = json.Unmarshal(dat, &contents)
	}
	return contents, err
}

func writeStickerpackContents(path string, contents StickerpackContents) error {
	contentsJson, err := json.MarshalIndent(contents, "", "  ")
	if err == nil {
		err = ioutil.WriteFile(path, contentsJson, 0644)
	}
	return err
}

func readStickerContents(path string) (StickerContents, error) {
	var contents StickerContents
	dat, err := ioutil.ReadFile(path)
	if err == nil {
		err = json.Unmarshal(dat, &contents)
	}
	return contents, err
}

func writeStickerContents(path string, contents StickerContents) error {
	contentsJson, err := json.MarshalIndent(contents, "", "  ")
	if err == nil {
		err = ioutil.WriteFile(path, contentsJson, 0644)
	}
	return err
}

func readImagesetContents(path string) (ImagesetContents, error) {
	var contents ImagesetContents
	dat, err := ioutil.ReadFile(path)
	if err == nil {
		err = json.Unmarshal(dat, &contents)
	}
	return contents, err
}

func writeImagesetContents(path string, contents ImagesetContents) error {
	contentsJson, err := json.MarshalIndent(contents, "", "  ")
	if err == nil {
		err = ioutil.WriteFile(path, contentsJson, 0644)
	}
	return err
}

func makeValidExtensionList(selected []string) []string {
	allowed := make([]string, 0)

	if selected == nil || len(selected) == 0 {
		allowed = append(allowed, "jpg", "jpeg", "png", "gif", "tif", "tiff")
	} else {
		allowed = append(allowed, selected...)
		for _, value := range selected {
			if value == "jpg" {
				allowed = append(allowed, "jpeg")
			} else if value == "tif" {
				allowed = append(allowed, "tiff")
			}
		}
	}

	return allowed
}

func readManifest(path string) []Manifest {
	allManifest := make([]Manifest, 0)
	theManifest := Manifest{}
	lines := fileutil.ReadLines(path)
	for _, line := range lines {
		if len(line) > 0 {
			if strings.HasPrefix(line, "# ") == true {
				// comment line, ignore
			} else if strings.HasPrefix(line, "= ") == true {
				parts := strings.Split(line[2:], ",")
				if len(parts) >= 2 {
					setting := ManifestSetting{}
					setting.key = strings.TrimSpace(parts[0])
					for _, value := range parts[1:] {
						setting.values = append(setting.values, strings.TrimSpace(value))
					}
					theManifest.settings = append(theManifest.settings, setting)
				} else {
					fmt.Printf("Bad setting in manifest: %v\n", line)
				}
			} else if strings.HasPrefix(line, "--") == true {
				allManifest = append(allManifest, theManifest)
				theManifest = Manifest{}
			} else {
				theManifest.files = append(theManifest.files, line)
			}
		}
	}
	allManifest = append(allManifest, theManifest)
	return allManifest
}

func collectFileList(srcDirPath string, allowedExtensions []string, manifestFiles []string) ([]string, error) {
	outList := make([]string, 0)
	baseList := fileutil.ShallowDirectory(srcDirPath)
	extensions := allowedExtensions
	if extensions == nil {
		extensions = makeValidExtensionList(nil)
	}
	if manifestFiles != nil && len(manifestFiles) != 0 {
		for _, value := range manifestFiles {
			ext := filepath.Ext(value)
			if stringutil.StringInSlice(value, baseList) == true && len(ext) > 1 && stringutil.StringInSlice(ext[1:], extensions) == true {
				outList = append(outList, filepath.Join(srcDirPath, value))
			}
		}

		if len(outList) == len(manifestFiles) {
			return outList, nil
		} else {
			return nil, errors.New("Missing files from manifest")
		}
	} else {
		for _, value := range baseList {
			ext := filepath.Ext(value)
			if len(ext) > 1 && stringutil.StringInSlice(ext[1:], extensions) {
				outList = append(outList, filepath.Join(srcDirPath, value))
			}
		}
		return outList, nil
	}
}

func formatForPath(path string) ImageFormat {
	switch ext := filepath.Ext(path); ext {
	case ".jpeg":
		return formatJPEG
	case ".jpg":
		return formatJPEG
	case ".png":
		return formatPNG
	case ".gif":
		return formatGIF
	case ".tiff":
		return formatTIFF
	case ".tif":
		return formatTIFF
	default:
		return formatUnchanged
	}
}

func formatForString(str string) ImageFormat {
	switch str {
	case "jpg":
		return formatJPEG
	case "png":
		return formatPNG
	case "tif":
		return formatTIFF
	}
	return formatUnchanged
}

func packageForString(str string) PackageType {
	switch str {
	case "stickerpack":
		return packageStickerPack
	case "imageset":
		return packageImageSet
	case "iconset":
		return packageIconSet
	case "icns":
		return packageIcns
	case "catalog":
		return packageCatalog
	}
	return packageNone
}

func presetForString(str string) PresetType {
	switch str {
	case "smallSticker":
		return presetSmallSticker
	case "mediumSticker":
		return presetMediumSticker
	case "largeSticker":
		return presetLargeSticker
	case "presetThumb256":
		return presetThumb256
	case "imageSet":
		return presetImageSet
	case "imageSetForLargeSticker":
		return presetImageSetForLargeSticker
	case "largeStickerWithImageSet":
		return presetLargeStickerWithImageSet
	}
	return presetNone
}

func changeExtensionForFormat(path string, format ImageFormat) string {
	switch format {
	case formatJPEG:
		return fileutil.ChangeExtension(path, ".jpg")
	case formatPNG:
		return fileutil.ChangeExtension(path, ".png")
	case formatTIFF:
		return fileutil.ChangeExtension(path, ".tif")
	case formatGIF:
		return fileutil.ChangeExtension(path, ".gif")
	case formatUnchanged:
		return path
	}
	return path
}

func clearCatalog(dirPath string) {
	for _, file := range fileutil.ShallowDirectory(dirPath) {
		err := os.RemoveAll(filepath.Join(dirPath, file))
		if err != nil {
			fmt.Printf("Error deleting sticker pack contents: %v\n", err)
		}
	}
	var contents CatalogContents
	contents.Info.Author = "xcode"
	contents.Info.Version = 1
	path := filepath.Join(dirPath, "Contents.json")
	writeCatalogContents(path, contents)
}

func clearFolder(dirPath string) {
	for _, file := range fileutil.ShallowDirectory(dirPath) {
		err := os.RemoveAll(filepath.Join(dirPath, file))
		if err != nil {
			fmt.Printf("Error deleting folder contents: %v\n", err)
		}
	}
}

func processImageSetWithSticker(srcPath string, config Configuration, plan ProcessPlan) []ProcessResult {
	results := make([]ProcessResult, 0)

	srcFileName := filepath.Base(srcPath)
	setName := fileutil.ChangeExtension(srcFileName, "")

	setDirPath := filepath.Join(config.dstDirPath, fileutil.ChangeExtension(setName, ".imageset"))
	setContentsPath := filepath.Join(setDirPath, "Contents.json")
	setImagePath := filepath.Join(setDirPath, srcFileName)

	os.Mkdir(setDirPath, os.ModePerm)

	contents := ImagesetContents{}
	contents.Info.Author = "xcode"
	contents.Info.Version = 1

	var srcImage image.Image

	// 1x
	dstPath := setImagePath
	neededWidth := 206
	neededHeight := 206

	srcImage = imaging.New(1, 1, color.NRGBA{0, 0, 0, 0})

	dstImage := srcImage
	dstImage = imaging.Fit(srcImage, neededWidth, neededHeight, imaging.Lanczos)

	err := imaging.Save(dstImage, dstPath)
	if err != nil {
		results = append(results, ProcessResult{srcPath, dstPath, true, fmt.Errorf("Save failed: %v", err)})
		return results
	}

	results = append(results, ProcessResult{srcPath, dstPath, false, nil})

	imageRecord := ImagesetContentsImage{Idiom: "universal", Scale: "1x", Filename: filepath.Base(dstPath)}
	contents.Images = append(contents.Images, imageRecord)

	// 2x
	dstPath = fileutil.ChangeSuffix(setImagePath, "", "@2x")
	neededWidth = 412
	neededHeight = 412

	srcImage, err = imaging.Open(srcPath)
	if err != nil {
		results = append(results, ProcessResult{srcPath, dstPath, true, fmt.Errorf("Open failed: %v", err)})
		return results
	}

	dstImage = srcImage
	dstImage = imaging.Fit(srcImage, neededWidth, neededHeight, imaging.Lanczos)

	err = imaging.Save(dstImage, dstPath)
	if err != nil {
		results = append(results, ProcessResult{srcPath, dstPath, true, fmt.Errorf("Save failed: %v", err)})
		return results
	}

	results = append(results, ProcessResult{srcPath, dstPath, false, nil})

	imageRecord = ImagesetContentsImage{Idiom: "universal", Scale: "2x", Filename: filepath.Base(dstPath)}
	contents.Images = append(contents.Images, imageRecord)

	// 3x
	dstPath = fileutil.ChangeSuffix(setImagePath, "", "@3x")
	neededWidth = 412
	neededHeight = 412

	srcImage = imaging.New(1, 1, color.NRGBA{0, 0, 0, 0})

	dstImage = srcImage
	dstImage = imaging.Fit(srcImage, neededWidth, neededHeight, imaging.Lanczos)

	err = imaging.Save(dstImage, dstPath)
	if err != nil {
		results = append(results, ProcessResult{srcPath, dstPath, true, fmt.Errorf("Save failed: %v", err)})
		return results
	}

	results = append(results, ProcessResult{srcPath, dstPath, false, nil})

	imageRecord = ImagesetContentsImage{Idiom: "universal", Scale: "3x", Filename: filepath.Base(dstPath)}
	contents.Images = append(contents.Images, imageRecord)

	err = writeImagesetContents(setContentsPath, contents)
	if err != nil {
		fmt.Printf("Error writing imageset: %v\n", err)
	}

	validateStickerFileSize(dstPath, srcFileName)

	return results
}

func validateStickerFileSize(filePath string, reportFileName string) {
	file, err := os.Open(filePath)
	if err != nil {
		// handle the error here
		return
	}
	defer file.Close()

	// get the file size
	stat, err := file.Stat()
	if err != nil {
		return
	}

	size := stat.Size()
	if size > 512000 {
		fmt.Printf("%v sticker image is too large. (%v > 512000)", reportFileName, size)
	}
}

func clearStickerPack(dirPath string) {
	contentPath := filepath.Join(dirPath, "Contents.json")
	contents, err := readStickerpackContents(contentPath)
	if err != nil {
		fmt.Printf("Error reading sticker pack contents: %v\n", err)
		return
	}
	for _, sticker := range contents.Stickers {
		err = os.RemoveAll(filepath.Join(dirPath, sticker.Filename))
		if err != nil {
			fmt.Printf("Error deleting sticker pack contents: %v\n", err)
		}
	}
	contents.Stickers = make([]StickerpackContentsSticker, 0)
	err = writeStickerpackContents(contentPath, contents)
	if err != nil {
		fmt.Printf("Error writing sticker pack contents: %v\n", err)
	}
}

func insertStickerToPack(newStickerPath string) string {
	packDirPath, filename := filepath.Split(newStickerPath)
	contentsPath := filepath.Join(packDirPath, "Contents.json")
	contents, err := readStickerpackContents(contentsPath)
	if err != nil {
		fmt.Printf("Error reading sticker pack contents: %v\n", err)
		return ""
	}

	stickerDirPath := filepath.Join(packDirPath, fileutil.ChangeExtension(filename, ".sticker"))
	stickerContentsPath := filepath.Join(stickerDirPath, "Contents.json")
	stickerImagePath := filepath.Join(stickerDirPath, filename)

	os.Mkdir(stickerDirPath, os.ModePerm)
	var stickerContents StickerContents
	stickerContents.Info.Version = 1
	stickerContents.Info.Author = "xcode"
	stickerContents.Properties.Filename = filename
	err = writeStickerContents(stickerContentsPath, stickerContents)
	if err != nil {
		fmt.Printf("Error writing sticker contents: %v\n", err)
	}
	contents.Stickers = append(contents.Stickers, StickerpackContentsSticker{Filename: fileutil.ChangeExtension(filename, ".sticker")})

	err = writeStickerpackContents(contentsPath, contents)
	if err != nil {
		fmt.Printf("Error writing sticker pack contents: %v\n", err)
	}

	return stickerImagePath
}

func imageSetPathFromImagePath(imagePath string) string {
	dir, file := filepath.Split(imagePath)
	file = fileutil.ChangeExtension(file, ".imageset")
	file = fileutil.ChangeSuffix(file, "@2x", "")
	file = fileutil.ChangeSuffix(file, "@3x", "")
	setPath := filepath.Join(dir, file)
	return setPath
}

func clearImageSet(newImagePath string) {
	setPath := imageSetPathFromImagePath(newImagePath)

	err := os.RemoveAll(setPath)
	if err != nil {
		fmt.Printf("Error deleting imageset: %v\n", err)
	}

	err = os.Mkdir(setPath, 0755)
	if err != nil {
		fmt.Printf("Error creating imageset: %v\n", err)
	}

	contentsPath := filepath.Join(setPath, "Contents.json")
	contents := ImagesetContents{}
	contents.Info.Author = "xcode"
	contents.Info.Version = 1
	err = writeImagesetContents(contentsPath, contents)
	if err != nil {
		fmt.Printf("Error writing imageset: %v\n", err)
	}
}

func insertImageToSet(newImagePath string) string {
	setPath := imageSetPathFromImagePath(newImagePath)
	contentsPath := filepath.Join(setPath, "Contents.json")
	contents, err := readImagesetContents(contentsPath)
	if err != nil {
		fmt.Printf("Error reading imageset: %v\n", err)
	}

	_, newFileName := filepath.Split(newImagePath)
	imageRecord := ImagesetContentsImage{Idiom: "universal", Filename: newFileName}
	if fileutil.HasSuffix(newFileName, "@2x") == true {
		imageRecord.Scale = "2x"
	} else if fileutil.HasSuffix(newFileName, "@3x") == true {
		imageRecord.Scale = "3x"
	} else {
		imageRecord.Scale = "1x"
	}

	contents.Images = append(contents.Images, imageRecord)

	err = writeImagesetContents(contentsPath, contents)
	if err != nil {
		fmt.Printf("Error writing imageset: %v\n", err)
	}

	outImagePath := filepath.Join(setPath, newFileName)
	return outImagePath
}

func processIconSet(srcPath string, config Configuration, plan ProcessPlan) []ProcessResult {
	dstFolderPath := config.dstDirPath

	results := make([]ProcessResult, 0)

	fmt.Printf("Processing: %v\n", filepath.Base(srcPath))

	contentsPath := filepath.Join(dstFolderPath, "Contents.json")
	contents, err := readImagesetContents(contentsPath)
	if err != nil {
		results = append(results, ProcessResult{srcPath, "", false, err})
		return results
	}

	for idx, element := range contents.Images {
		neededSize := element.Size
		neededScale := element.Scale
		currentFilename := element.Filename

		if len(neededSize) == 0 {
			results = append(results, ProcessResult{srcPath, "", true, fmt.Errorf("Missing Size")})
			return results
		}
		if len(neededScale) == 0 {
			results = append(results, ProcessResult{srcPath, "", true, fmt.Errorf("Missing Scale")})
			return results
		}

		sizeParts := strings.Split(neededSize, "x")
		scaleParts := strings.Split(neededScale, "x")

		scale, err := strconv.ParseFloat(scaleParts[0], 64)
		width, err := strconv.ParseFloat(sizeParts[0], 64)
		height, err := strconv.ParseFloat(sizeParts[1], 64)

		neededWidth := int(width * scale)
		neededHeight := int(height * scale)

		if len(currentFilename) != 0 {
			os.Remove(filepath.Join(dstFolderPath, currentFilename))
			element.Filename = ""
		}

		var useFormat ImageFormat

		if len(plan.requiredSuffix) > 0 && fileutil.HasSuffix(srcPath, plan.requiredSuffix) == false {
			results = append(results, ProcessResult{srcPath, "", false, fmt.Errorf("Source does not have required suffix: %v", plan.requiredSuffix)})
			return results
		}

		dstName := filepath.Base(srcPath)

		useFormat = formatForPath(srcPath)
		if useFormat == formatUnchanged {
			results = append(results, ProcessResult{srcPath, "", true, fmt.Errorf("Unsupported source image format")})
			return results
		}
		if plan.outputFormat != formatUnchanged {
			useFormat = plan.outputFormat
			dstName = changeExtensionForFormat(dstName, useFormat)
		}

		newSuffix := fmt.Sprintf("-%v-%v", neededSize, neededScale)
		dstName = fileutil.ChangeSuffix(dstName, "", newSuffix)

		dstPath := filepath.Join(dstFolderPath, dstName)

		srcImage, err := imaging.Open(srcPath)
		if err != nil {
			results = append(results, ProcessResult{srcPath, dstPath, true, fmt.Errorf("Open failed: %v", err)})
			return results
		}

		dstImage := srcImage
		dstImage = imaging.Fill(srcImage, neededWidth, neededHeight, imaging.Center, imaging.Lanczos)

		err = imaging.Save(dstImage, dstPath)
		if err != nil {
			results = append(results, ProcessResult{srcPath, dstPath, true, fmt.Errorf("Save failed: %v", err)})
			continue
		}

		contents.Images[idx].Filename = dstName

		results = append(results, ProcessResult{srcPath, dstPath, false, nil})
	}

	err = writeImagesetContents(contentsPath, contents)
	if err != nil {
		results = append(results, ProcessResult{srcPath, "", true, err})
	}

	return results
}

func processIcns(srcPath string, config Configuration, plan ProcessPlan) []ProcessResult {
	dstFilePath := config.dstDirPath
	dstFolderPath := fileutil.ChangeExtension(dstFilePath, ".iconset")

	err := os.Mkdir(dstFolderPath, 0755)
	if err != nil {
		fmt.Printf("Error creating icns: %v\n", err)
	}

	results := make([]ProcessResult, 0)

	fmt.Printf("Processing: %v\n", filepath.Base(srcPath))

	sizes := []struct {
		scale float64
		size  float64
	}{
		{1, 16},
		{2, 16},
		{1, 32},
		{2, 32},
		{1, 128},
		{2, 128},
		{1, 256},
		{2, 256},
		{1, 512},
		{2, 512},
	}

	for _, element := range sizes {
		scale := element.scale
		width := element.size
		height := element.size

		neededWidth := int(width * scale)
		neededHeight := int(height * scale)

		var useFormat ImageFormat

		if len(plan.requiredSuffix) > 0 && fileutil.HasSuffix(srcPath, plan.requiredSuffix) == false {
			results = append(results, ProcessResult{srcPath, "", false, fmt.Errorf("Source does not have required suffix: %v", plan.requiredSuffix)})
			return results
		}

		dstName := "icon_" + filepath.Ext(srcPath)

		useFormat = formatForPath(srcPath)
		if useFormat == formatUnchanged {
			results = append(results, ProcessResult{srcPath, "", true, fmt.Errorf("Unsupported source image format")})
			return results
		}
		if plan.outputFormat != formatUnchanged {
			useFormat = plan.outputFormat
			dstName = changeExtensionForFormat(dstName, useFormat)
		}

		newSuffix := fmt.Sprintf("%vx%v", width, height)
		if scale == 2 {
			newSuffix = newSuffix + "@2x"
		}
		dstName = fileutil.ChangeSuffix(dstName, "", newSuffix)

		dstPath := filepath.Join(dstFolderPath, dstName)

		srcImage, err := imaging.Open(srcPath)
		if err != nil {
			results = append(results, ProcessResult{srcPath, dstPath, true, fmt.Errorf("Open failed: %v", err)})
			return results
		}

		dstImage := srcImage
		dstImage = imaging.Fill(srcImage, neededWidth, neededHeight, imaging.Center, imaging.Lanczos)

		err = imaging.Save(dstImage, dstPath)
		if err != nil {
			results = append(results, ProcessResult{srcPath, dstPath, true, fmt.Errorf("Save failed: %v", err)})
			continue
		}

		results = append(results, ProcessResult{srcPath, dstPath, false, nil})
	}

	_, err = shellutil.RunCommandParts([]string{"iconutil", "--convert", "icns", "--output", dstFilePath, dstFolderPath}, false, true, nil)
	if err != nil {
		results = append(results, ProcessResult{srcPath, "", true, fmt.Errorf("Convert failed: %v", err)})
	}

	os.RemoveAll(dstFolderPath)

	return results
}

func processImage(srcPath string, config Configuration, plans []ProcessPlan) []ProcessResult {
	dstFolderPath := config.dstDirPath

	results := make([]ProcessResult, 0)

	fmt.Printf("Processing: %v\n", filepath.Base(srcPath))

	oneTimeDone := false

	for _, plan := range plans {
		var useFormat ImageFormat
		var err error

		if len(plan.requiredSuffix) > 0 && fileutil.HasSuffix(srcPath, plan.requiredSuffix) == false {
			results = append(results, ProcessResult{srcPath, "", false, fmt.Errorf("Source does not have required suffix: %v", plan.requiredSuffix)})
			continue
		}

		dstName := filepath.Base(srcPath)

		useFormat = formatForPath(srcPath)
		if useFormat == formatUnchanged {
			results = append(results, ProcessResult{srcPath, "", true, fmt.Errorf("Unsupported source image format")})
			continue
		}
		if plan.outputFormat != formatUnchanged {
			useFormat = plan.outputFormat
			dstName = changeExtensionForFormat(dstName, useFormat)
		}

		dstPath := filepath.Join(dstFolderPath, dstName)

		if len(plan.removeSuffix) > 0 || len(plan.addSuffix) > 0 {
			dstPath = fileutil.ChangeSuffix(dstPath, plan.removeSuffix, plan.addSuffix)
		}

		srcImage, err := imaging.Open(srcPath)
		if err != nil {
			results = append(results, ProcessResult{srcPath, dstPath, true, fmt.Errorf("Open failed: %v", err)})
			continue
		}

		dstImage := srcImage
		if plan.scale != 0 {
			if plan.scale != 1 {
				newWidth := int(float64(srcImage.Bounds().Dx()) * plan.scale)
				newHeight := int(float64(srcImage.Bounds().Dy()) * plan.scale)
				dstImage = imaging.Fit(srcImage, newWidth, newHeight, imaging.Lanczos)
			}
		} else if plan.boxWidth == 0 && plan.boxHeight == 0 {
			// no action
		} else {
			if plan.boxWidth == 0 || plan.boxHeight == 0 {
				dstImage = imaging.Resize(srcImage, plan.boxWidth, plan.boxHeight, imaging.Lanczos)
			} else {
				dstImage = imaging.Fit(srcImage, plan.boxWidth, plan.boxHeight, imaging.Lanczos)
			}
		}

		if config.outputPackage == packageStickerPack {
			dstPath = insertStickerToPack(dstPath)
		} else if config.outputPackage == packageImageSet {
			if oneTimeDone == false {
				clearImageSet(dstPath)
				oneTimeDone = true
			}
			dstPath = insertImageToSet(dstPath)
		}

		err = imaging.Save(dstImage, dstPath)
		if err != nil {
			results = append(results, ProcessResult{srcPath, dstPath, true, fmt.Errorf("Save failed: %v", err)})
			continue
		}

		results = append(results, ProcessResult{srcPath, dstPath, false, nil})
	}

	return results
}

func processImages(srcPaths []string, config Configuration, plans []ProcessPlan) ([]ProcessResult, error) {
	if config.outputPackage == packageStickerPack {
		if strings.HasSuffix(config.dstDirPath, ".stickerpack") == false {
			return nil, fmt.Errorf("Destination (%v) is not a .stickerpack directory", config.dstDirPath)
		}
		if config.outputPackageReplace == true {
			clearStickerPack(config.dstDirPath)
		}
	} else if config.outputPackage == packageIconSet {
		if strings.HasSuffix(config.dstDirPath, ".stickersiconset") == false && strings.HasSuffix(config.dstDirPath, ".appiconset") == false {
			return nil, fmt.Errorf("Destination (%v) is not a .stickersiconset or .appiconset directory", config.dstDirPath)
		}
		if len(srcPaths) != 1 {
			return nil, fmt.Errorf("Only 1 source image allowed when using iconset package")
		}

		fmt.Printf("Processing %v image...\n", len(srcPaths))
		results := make([]ProcessResult, 0)
		for _, srcPath := range srcPaths {
			oneResult := processIconSet(srcPath, config, plans[0])
			results = append(results, oneResult...)
		}
		return results, nil
	} else if config.outputPackage == packageIcns {
		if strings.HasSuffix(config.dstDirPath, ".icns") == false {
			return nil, fmt.Errorf("Destination (%v) is not a .icns directory", config.dstDirPath)
		}
		if len(srcPaths) != 1 {
			return nil, fmt.Errorf("Only 1 source image allowed when using icns package")
		}

		fmt.Printf("Processing %v image...\n", len(srcPaths))
		results := make([]ProcessResult, 0)
		for _, srcPath := range srcPaths {
			oneResult := processIcns(srcPath, config, plans[0])
			results = append(results, oneResult...)
		}
		return results, nil
	} else if config.outputPackage == packageCatalog && config.preset == presetImageSetForLargeSticker {
		if strings.HasSuffix(config.dstDirPath, ".xcassets") == false {
			return nil, fmt.Errorf("Destination (%v) is not a .xcassets directory", config.dstDirPath)
		}
		if config.outputPackageReplace == true {
			clearCatalog(config.dstDirPath)
		}

		if len(srcPaths) == 1 {
			fmt.Printf("Processing %v image...\n", len(srcPaths))
		} else {
			fmt.Printf("Processing %v images...\n", len(srcPaths))
		}
		results := make([]ProcessResult, 0)
		manifestNames := make([]string, 0)
		for _, srcPath := range srcPaths {
			oneResult := processImageSetWithSticker(srcPath, config, plans[0])
			results = append(results, oneResult...)

			manifestNames = append(manifestNames, fileutil.ChangeExtension(filepath.Base(srcPath), ""))
		}
		if len(config.outManifest) > 0 {
			manifestJson, err := json.MarshalIndent(manifestNames, "", "  ")
			if err == nil {
				err = ioutil.WriteFile(config.outManifest, manifestJson, 0644)
			}
		}
		return results, nil
	}
	if config.outputPackageReplace == true {
		clearFolder(config.dstDirPath)
	}
	if len(srcPaths) == 1 {
		fmt.Printf("Processing %v image...\n", len(srcPaths))
	} else {
		fmt.Printf("Processing %v images...\n", len(srcPaths))
	}
	results := make([]ProcessResult, 0)
	for _, srcPath := range srcPaths {
		oneResult := processImage(srcPath, config, plans)
		results = append(results, oneResult...)
	}
	return results, nil
}

func planPreset(plan ProcessPlan, preset PresetType) []ProcessPlan {
	plans := make([]ProcessPlan, 0)
	switch preset {
	case presetSmallSticker:
		plans = append(plans, ProcessPlan{boxWidth: 300, boxHeight: 300, outputFormat: formatPNG, outputPackage: plan.outputPackage})
	case presetMediumSticker:
		plans = append(plans, ProcessPlan{boxWidth: 408, boxHeight: 408, outputFormat: formatPNG, outputPackage: plan.outputPackage})
	case presetLargeSticker:
		plans = append(plans, ProcessPlan{boxWidth: 618, boxHeight: 618, outputFormat: formatPNG, outputPackage: plan.outputPackage})
	case presetThumb256:
		plans = append(plans, ProcessPlan{boxWidth: 256, boxHeight: 256, outputFormat: plan.outputFormat, outputPackage: plan.outputPackage})
	case presetImageSet:
		plans = append(plans, ProcessPlan{scale: 1.0, requiredSuffix: "@3x", outputFormat: plan.outputFormat, outputPackage: plan.outputPackage})
		plans = append(plans, ProcessPlan{scale: 0.666666, requiredSuffix: "@3x", removeSuffix: "@3x", addSuffix: "@2x", outputFormat: plan.outputFormat, outputPackage: plan.outputPackage})
		plans = append(plans, ProcessPlan{scale: 0.333333, requiredSuffix: "@3x", removeSuffix: "@3x", addSuffix: "", outputFormat: plan.outputFormat, outputPackage: plan.outputPackage})
	case presetImageSetForLargeSticker:
		plans = append(plans, ProcessPlan{boxWidth: 618, boxHeight: 618, outputFormat: formatPNG, outputPackage: plan.outputPackage})
	case presetLargeStickerWithImageSet:
		plans = append(plans, ProcessPlan{boxWidth: 206, boxHeight: 206, addSuffix: "@1x", outputFormat: formatPNG, outputPackage: plan.outputPackage})
		plans = append(plans, ProcessPlan{boxWidth: 618, boxHeight: 618, addSuffix: "@3x", outputFormat: formatPNG, outputPackage: plan.outputPackage})
	}
	return plans
}

func processManifestSettings(config *Configuration, settings []ManifestSetting) {
	for _, setting := range settings {
		switch setting.key {
		case "src":
			path := setting.values[0]
			if strings.HasPrefix(path, "~~") {
				path = "." + path[2:]
				root, _ := filepath.Split(config.manifestPath)
				path = filepath.Join(root, path)
			} else {
				path, _ = fileutil.ExpandTilde(path)
			}
			config.srcDirPath = path
		case "dst":
			path := setting.values[0]
			if strings.HasPrefix(path, "~~") {
				path = "." + path[2:]
				root, _ := filepath.Split(config.manifestPath)
				path = filepath.Join(root, path)
			} else {
				path, _ = fileutil.ExpandTilde(path)
			}
			config.dstDirPath = path
		case "preset":
			newPreset := presetForString(setting.values[0])
			if newPreset != presetNone {
				config.preset = newPreset
			}
		case "valid-format":
			config.validExtensions = setting.values
		case "out-manifest":
			path := setting.values[0]
			if strings.HasPrefix(path, "~~") {
				path = "." + path[2:]
				root, _ := filepath.Split(config.manifestPath)
				path = filepath.Join(root, path)
			} else {
				path, _ = fileutil.ExpandTilde(path)
			}
			config.outManifest = path
		case "out-format":
			newFormat := formatForString(setting.values[0])
			if newFormat != formatUnchanged {
				config.outputFormat = newFormat
			}
		case "out-package":
			newPackage := packageForString(setting.values[0])
			if newPackage != packageNone {
				config.outputPackage = newPackage
			}
		case "out-package-replace":
			config.outputPackageReplace, _ = strconv.ParseBool(setting.values[0])
		case "scale":
			config.scale, _ = strconv.ParseFloat(setting.values[0], 64)
		case "max-px":
			value, _ := strconv.Atoi(setting.values[0])
			config.maxHeight = value
			config.maxHeight = value
		case "max-width-px":
			config.maxWidth, _ = strconv.Atoi(setting.values[0])
		case "max-height-px":
			config.maxHeight, _ = strconv.Atoi(setting.values[0])
		}
	}
}

func validateConfiguration(config *Configuration) error {
	if config.srcDirPath == "" {
		config.valid = false
		config.err = fmt.Errorf("Missing src.")
		return config.err
	}

	if config.dstDirPath == "" {
		config.valid = false
		config.err = fmt.Errorf("Missing dst.")
		return config.err
	}

	if config.scale != 0 {
		if config.maxWidth != 0 || config.maxHeight != 0 {
			config.valid = false
			config.err = fmt.Errorf("Can not specify scale and max-width / max-height.")
			return config.err
		}
	}

	return nil
}

func processConfiguration(config Configuration) {
	var manifestFiles []string
	baseConfig := config

	if len(config.manifestPath) != 0 {
		manifests := readManifest(config.manifestPath)
		for _, manifest := range manifests {
			currentConfig := baseConfig
			processManifestSettings(&currentConfig, manifest.settings)
			manifestFiles = manifest.files
			processOneConfiguration(currentConfig, manifestFiles)
		}
	} else {
		processOneConfiguration(config, manifestFiles)
	}
}

func processOneConfiguration(config Configuration, manifestFiles []string) {
	configErr := validateConfiguration(&config)
	if configErr != nil {
		fmt.Println(configErr)
		return
	}

	haveDir, _ := fileutil.IsDir(config.srcDirPath)
	if haveDir == false {
		dir, file := filepath.Split(config.srcDirPath)

		config.srcDirPath = dir
		manifestFiles = append(manifestFiles, file)
	}

	files, err := collectFileList(config.srcDirPath, config.validExtensions, manifestFiles)
	if err != nil {
		fmt.Printf("Error: %v\n", err)
	}

	plans := make([]ProcessPlan, 1)
	plans[0].scale = config.scale
	plans[0].boxWidth = config.maxWidth
	plans[0].boxHeight = config.maxHeight
	plans[0].outputFormat = config.outputFormat
	plans[0].outputPackage = config.outputPackage

	if config.preset != presetNone {
		plans = planPreset(plans[0], config.preset)
	}

	results, err := processImages(files, config, plans)
	if err != nil {
		fmt.Printf("Error: %v\n", err)
	} else {
		for _, result := range results {
			if result.err != nil {
				fmt.Printf("Error (%v) for file (%v)\n", result.err, result.inPath)
			}
		}
	}
}

func configurationFromArgs(args []string) Configuration {
	var config Configuration
	kingpin.MustParse(app.Parse(args[1:]))

	if *srcFlag != "" {
		config.srcDirPath = *srcFlag
	}

	if *dstFlag != "" {
		config.dstDirPath = *dstFlag
	}

	if *manifestFlag != "" {
		config.manifestPath = *manifestFlag
		path, _ := filepath.Abs(config.manifestPath)
		config.manifestPath = path
	}

	if *presetFlag != "" {
		config.preset = presetForString(*presetFlag)
	}

	config.validExtensions = makeValidExtensionList(*validTypesFlag)

	if *outTypeFlag != "" {
		config.outputFormat = formatForString(*outTypeFlag)
	}

	if *outPackageFlag != "" {
		config.outputPackage = packageForString(*outPackageFlag)
	}

	config.outputPackageReplace = *outPackageReplaceFlag

	if *scaleFlag != 0 {
		if *maxPxFlag != 0 || *maxWidthPxFlag != 0 || *maxHeightPxFlag != 0 {
			config.err = fmt.Errorf("Can not specify scale and any of max-px, max-width-px, max-height-px.")
			return config
		}
	} else if *maxPxFlag != 0 {
		if *maxWidthPxFlag != 0 || *maxHeightPxFlag != 0 {
			config.err = fmt.Errorf("Can not specify max-px and any of max-width-px, max-height-px.")
			return config
		}
	}

	if *scaleFlag != 0 {
		config.scale = *scaleFlag
	}

	if *maxPxFlag != 0 {
		config.maxWidth = *maxPxFlag
		config.maxHeight = *maxPxFlag
	}

	if *maxWidthPxFlag != 0 {
		config.maxWidth = *maxWidthPxFlag
	}

	if *maxHeightPxFlag != 0 {
		config.maxHeight = *maxHeightPxFlag
	}

	config.valid = true

	return config
}

func main() {
	kingpin.Version("0.0.3")
	config := configurationFromArgs(os.Args)
	if config.err != nil {
		fmt.Println(config.err)
	} else if config.valid == true {
		processConfiguration(config)
	}
}
