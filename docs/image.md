# 🍿 image

![Image](https://github.com/user-attachments/assets/4e8a686c-bf41-4989-9d74-1641ecf2835f)

Image viewer using the [Kitty Graphics Protocol](https://sw.kovidgoyal.net/kitty/graphics-protocol/).

Supported terminals:

- [kitty](https://sw.kovidgoyal.net/kitty/)
- [wezterm](https://wezfurlong.org/wezterm/)
- [ghostty](https://ghostty.org/)

In order to automatically display the image when openinng an image file,
you need to enable the `image` plugin in your `snacks` config.

Supported image formats:

- PNG
- JPEG/JPG
- GIF
- BMP
- WEBP

[ImageMagick](https://imagemagick.org/index.php) is required to convert images
to the supported formats (all except PNG).

<!-- docgen -->

## 📦 Setup

```lua
-- lazy.nvim
{
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    image = {
      -- your image configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
  }
}
```

## ⚙️ Config

```lua
---@class snacks.image.Config
---@field file? string
{}
```

## 📚 Types

```lua
---@alias snacks.image.Dim {col: number, row: number, width: number, height: number}
```

## 📦 Module

```lua
---@class snacks.Image
---@field id number
---@field buf number
---@field wins table<number, snacks.image.Dim>
---@field opts snacks.image.Config
---@field file string
---@field _convert uv.uv_process_t?
Snacks.image = {}
```

### `Snacks.image.new()`

```lua
---@param buf number
---@param opts? snacks.image.Config
Snacks.image.new(buf, opts)
```

### `Snacks.image.supports()`

```lua
---@param file string
Snacks.image.supports(file)
```

### `image:convert()`

```lua
image:convert()
```

### `image:create()`

```lua
image:create()
```

### `image:dim()`

```lua
---@param win number
---@return snacks.image.Dim
image:dim(win)
```

### `image:hide()`

```lua
---@param win? number
image:hide(win)
```

### `image:ready()`

```lua
image:ready()
```

### `image:render()`

```lua
---@param win number
image:render(win)
```

### `image:request()`

```lua
---@param opts table<string, string|number>|{data?: string}
image:request(opts)
```

### `image:update()`

```lua
image:update()
```
