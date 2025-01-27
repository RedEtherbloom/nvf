# TODO:
# - Add Texlab LSP settings:
#   - chktex
#   - symbols
#   - formatterLineLength
#   - bibtexFormatter
#   - latexFormatter
#   - latexindent
#   - completion
#   - inlayHints
#   - experimental
{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf;
  inherit (lib.types) listOf package str attrs ints;
  inherit
    (builtins)
    attrNames
    concatStringsSep
    elemAt
    filter
    hasAttr
    isAttrs
    length
    map
    throw
    toString
    ;
  inherit (lib.nvim.config) mkBool;

  cfg = config.vim.languages.tex;
  texlabCfg = cfg.lsp.texlab;
  builderCfg = cfg.build.builder;
in {
  options.vim.languages.tex.lsp.texlab = {
    enable = mkBool config.vim.languages.enableLSP "Whether to enable Tex LSP support (texlab)";

    package = mkOption {
      type = package;
      default = pkgs.texlab;
      description = "texlab package";
    };

    forwardSearch = {
      enable = mkBool false ''
        Whether to enable forward search.

        Enable this option if you want to have the compiled document appear in your chosen PDF viewer.

        For some options see [here](https://github.com/latex-lsp/texlab/wiki/Previewing).
        Note this is not all the options, but can act as a guide to help you allong with custom configs.
      '';
      package = mkOption {
        type = package;
        default = pkgs.okular;
        description = ''
          The package to use as your PDF viewer.
          This viewer needs to support Synctex.
        '';
      };
      executable = mkOption {
        type = str;
        default = "okular";
        description = ''
          Defines the executable of the PDF previewer. The previewer needs to support SyncTeX.
        '';
      };
      args = mkOption {
        type = listOf str;
        default = [
          "--unique"
          "file:%p#src:%l%f"
        ];
        description = ''
          Defines additional arguments that are passed to the configured previewer to perform the forward search.
          The placeholders %f, %p, %l will be replaced by the server.

          Placeholders:
            - %f: The path of the current TeX file.
            - %p: The path of the current PDF file.
            - %l: The current line number.
        '';
      };
    };

    diagnostics = {
      delay = mkOption {
        type = ints.positive;
        default = 300;
        description = "Delay in milliseconds before reporting diagnostics.";
      };
      allowedPatterns = mkOption {
        type = listOf str;
        default = [];
        description = ''
          A list of regular expressions used to filter the list of reported diagnostics.
          If specified, only diagnostics that match at least one of the specified patterns are sent to the client.

          See also texlab.diagnostics.ignoredPatterns.

          Hint: If both allowedPatterns and ignoredPatterns are set, then allowed patterns are applied first.
          Afterwards, the results are filtered with the ignored patterns.
        '';
      };
      ignoredPatterns = mkOption {
        type = listOf str;
        default = [];
        description = ''
          A list of regular expressions used to filter the list of reported diagnostics.
          If specified, only diagnostics that match none of the specified patterns are sent to the client.

          See also texlab.diagnostics.allowedPatterns.
        '';
      };
    };

    extraLuaSettings = mkOption {
      type = attrs;
      default = {};
      example = {
        formatterLineLength = 80;
      };
      description = ''
        For any options that do not have options provided through nvf this can be used to add them.
        Options already declared in nvf config will NOT be overridden.

        Options will be placed in:
        ```
        lspconfig.texlab.setup {
          settings = {
            texlab = {
              ...
              <nvf defined options>
              ...
              <extraLuaSettings>
            }
          }
        }
        ```
      '';
    };
  };

  config = mkIf (cfg.enable && (cfg.lsp.texlab.enable)) (
    let
      # ----- Setup Config -----
      # Command to start the LSP
      setupConfig.cmd = ["${texlabCfg.package}/bin/texlab"];

      # Create texlab settings section
      setupConfig.settings.texlab = (
        # -- General Settings --
        # -- Diagnostics --
        {
          diagnosticsDelay = texlabCfg.diagnostics.delay;
          diagnostics = {
            allowedPatterns = texlabCfg.diagnostics.allowedPatterns;
            ignoredPatterns = texlabCfg.diagnostics.ignoredPatterns;
          };
        }
        # -- Forward Search --
        // (
          if texlabCfg.forwardSearch.enable
          then {
            forwardSearch = {
              executable = "${texlabCfg.forwardSearch.package}/bin/${texlabCfg.forwardSearch.executable}";
              args = texlabCfg.forwardSearch.args;
            };
          }
          else {}
        )
        # -- Build --
        // (
          if cfg.build.enable
          then {
            build = {
              executable = "${builderCfg.package}/bin/${builderCfg.executable}";
              args = builderCfg.args;
              forwardSearchAfter = cfg.build.forwardSearchAfter;
              onSave = cfg.build.onSave;
              useFileList = cfg.build.useFileList;
              auxDirectory = cfg.build.auxDirectory;
              logDirectory = cfg.build.logDirectory;
              pdfDirectory = cfg.build.pdfDirectory;
              filename = cfg.build.filename;
            };
          }
          else {}
        )
        # -- Extra --
        // texlabCfg.extraLuaSettings
      );
    in {
      vim.lsp.lspconfig.sources.texlab = "lspconfig.texlab.setup(${lib.nvim.lua.toLuaObject setupConfig})";
    }
  );
}
