//! Type-safe internationalized messages for Loaf.
//! Serializes to {"v":1,"key":"...","args":[...]} or {"v":1,"raw":"..."}.

use serde::{Serialize, Serializer};
use std::fmt;

/// Compile-time checked localization key, matching `qml/Messages.qml`.
#[derive(
    Copy,
    Clone,
    Debug,
    PartialEq,
    Eq,
    PartialOrd,
    Ord,
    Hash,
    Serialize,
    strum::EnumIter,
    strum::EnumString,
    strum::Display,
)]
pub enum MessageKey {
    #[serde(rename = "info.no-preview")]
    #[strum(serialize = "info.no-preview")]
    InfoNoPreview,
    #[serde(rename = "info.missing")]
    #[strum(serialize = "info.missing")]
    InfoMissing,
    #[serde(rename = "info.folder-items")]
    #[strum(serialize = "info.folder-items")]
    InfoFolderItems,
    #[serde(rename = "info.archive-files")]
    #[strum(serialize = "info.archive-files")]
    InfoArchiveFiles,
    #[serde(rename = "info.encrypted-archive")]
    #[strum(serialize = "info.encrypted-archive")]
    InfoEncryptedArchive,
    #[serde(rename = "info.press-enter")]
    #[strum(serialize = "info.press-enter")]
    InfoPressEnter,
    #[serde(rename = "info.binary-file")]
    #[strum(serialize = "info.binary-file")]
    InfoBinaryFile,
    #[serde(rename = "drive.root")]
    #[strum(serialize = "drive.root")]
    DriveRoot,
    #[serde(rename = "drive.volume")]
    #[strum(serialize = "drive.volume")]
    DriveVolume,
    #[serde(rename = "name.empty")]
    #[strum(serialize = "name.empty")]
    NameEmpty,
    #[serde(rename = "name.reserved")]
    #[strum(serialize = "name.reserved")]
    NameReserved,
    #[serde(rename = "name.slash")]
    #[strum(serialize = "name.slash")]
    NameSlash,
    #[serde(rename = "name.invalid")]
    #[strum(serialize = "name.invalid")]
    NameInvalid,
    #[serde(rename = "name.too-long")]
    #[strum(serialize = "name.too-long")]
    NameTooLong,
    #[serde(rename = "place.home")]
    #[strum(serialize = "place.home")]
    PlaceHome,
    #[serde(rename = "place.pc")]
    #[strum(serialize = "place.pc")]
    PlacePc,
    #[serde(rename = "place.recent")]
    #[strum(serialize = "place.recent")]
    PlaceRecent,
    #[serde(rename = "place.starred")]
    #[strum(serialize = "place.starred")]
    PlaceStarred,
    #[serde(rename = "place.trash")]
    #[strum(serialize = "place.trash")]
    PlaceTrash,
    #[serde(rename = "notify.cancelled")]
    #[strum(serialize = "notify.cancelled")]
    NotifyCancelled,
    #[serde(rename = "notify.bookmark-added")]
    #[strum(serialize = "notify.bookmark-added")]
    NotifyBookmarkAdded,
    #[serde(rename = "notify.folder-missing")]
    #[strum(serialize = "notify.folder-missing")]
    NotifyFolderMissing,
    #[serde(rename = "notify.smb-missing")]
    #[strum(serialize = "notify.smb-missing")]
    NotifySmbMissing,
    #[serde(rename = "notify.keyring-error")]
    #[strum(serialize = "notify.keyring-error")]
    NotifyKeyringError,
    #[serde(rename = "notify.no-app-for-file")]
    #[strum(serialize = "notify.no-app-for-file")]
    NotifyNoAppForFile,
    #[serde(rename = "notify.app-missing")]
    #[strum(serialize = "notify.app-missing")]
    NotifyAppMissing,
    #[serde(rename = "notify.app-start-error")]
    #[strum(serialize = "notify.app-start-error")]
    NotifyAppStartError,
    #[serde(rename = "notify.app-default-set")]
    #[strum(serialize = "notify.app-default-set")]
    NotifyAppDefaultSet,
    #[serde(rename = "notify.cmd-error")]
    #[strum(serialize = "notify.cmd-error")]
    NotifyCmdError,
    #[serde(rename = "notify.script-error")]
    #[strum(serialize = "notify.script-error")]
    NotifyScriptError,
    #[serde(rename = "notify.pkexec-missing")]
    #[strum(serialize = "notify.pkexec-missing")]
    NotifyPkexecMissing,
    #[serde(rename = "notify.mtp-no-trash")]
    #[strum(serialize = "notify.mtp-no-trash")]
    NotifyMtpNoTrash,
    #[serde(rename = "notify.already-exists")]
    #[strum(serialize = "notify.already-exists")]
    NotifyAlreadyExists,
    #[serde(rename = "notify.create-error")]
    #[strum(serialize = "notify.create-error")]
    NotifyCreateError,
    #[serde(rename = "notify.renamed")]
    #[strum(serialize = "notify.renamed")]
    NotifyRenamed,
    #[serde(rename = "notify.cloudflared-installed")]
    #[strum(serialize = "notify.cloudflared-installed")]
    NotifyCloudflaredInstalled,
    #[serde(rename = "notify.cloudflared-install-failed")]
    #[strum(serialize = "notify.cloudflared-install-failed")]
    NotifyCloudflaredInstallFailed,
    #[serde(rename = "op.smb-disconnecting")]
    #[strum(serialize = "op.smb-disconnecting")]
    OpSmbDisconnecting,
    #[serde(rename = "op.smb-connecting")]
    #[strum(serialize = "op.smb-connecting")]
    OpSmbConnecting,
    #[serde(rename = "op.mtp-downloading")]
    #[strum(serialize = "op.mtp-downloading")]
    OpMtpDownloading,
    #[serde(rename = "op.opening-member")]
    #[strum(serialize = "op.opening-member")]
    OpOpeningMember,
    #[serde(rename = "op.mtp-previewing")]
    #[strum(serialize = "op.mtp-previewing")]
    OpMtpPreviewing,
    #[serde(rename = "op.mtp-transferring")]
    #[strum(serialize = "op.mtp-transferring")]
    OpMtpTransferring,
    #[serde(rename = "op.moving")]
    #[strum(serialize = "op.moving")]
    OpMoving,
    #[serde(rename = "op.copying")]
    #[strum(serialize = "op.copying")]
    OpCopying,
    #[serde(rename = "op.linking")]
    #[strum(serialize = "op.linking")]
    OpLinking,
    #[serde(rename = "op.trashing")]
    #[strum(serialize = "op.trashing")]
    OpTrashing,
    #[serde(rename = "op.deleting-phone")]
    #[strum(serialize = "op.deleting-phone")]
    OpDeletingPhone,
    #[serde(rename = "op.deleting")]
    #[strum(serialize = "op.deleting")]
    OpDeleting,
    #[serde(rename = "op.restoring")]
    #[strum(serialize = "op.restoring")]
    OpRestoring,
    #[serde(rename = "op.emptying-trash")]
    #[strum(serialize = "op.emptying-trash")]
    OpEmptyingTrash,
    #[serde(rename = "op.compressing")]
    #[strum(serialize = "op.compressing")]
    OpCompressing,
    #[serde(rename = "op.extracting")]
    #[strum(serialize = "op.extracting")]
    OpExtracting,
    #[serde(rename = "op.mtp-creating")]
    #[strum(serialize = "op.mtp-creating")]
    OpMtpCreating,
    #[serde(rename = "op.mtp-renaming")]
    #[strum(serialize = "op.mtp-renaming")]
    OpMtpRenaming,
    #[serde(rename = "outcome.smb-connected")]
    #[strum(serialize = "outcome.smb-connected")]
    OutcomeSmbConnected,
    #[serde(rename = "outcome.mtp-opened")]
    #[strum(serialize = "outcome.mtp-opened")]
    OutcomeMtpOpened,
    #[serde(rename = "outcome.mtp-transfer-complete")]
    #[strum(serialize = "outcome.mtp-transfer-complete")]
    OutcomeMtpTransferComplete,
    #[serde(rename = "outcome.trashed")]
    #[strum(serialize = "outcome.trashed")]
    OutcomeTrashed,
    #[serde(rename = "outcome.mtp-deleted")]
    #[strum(serialize = "outcome.mtp-deleted")]
    OutcomeMtpDeleted,
    #[serde(rename = "outcome.deleted")]
    #[strum(serialize = "outcome.deleted")]
    OutcomeDeleted,
    #[serde(rename = "outcome.delete-err")]
    #[strum(serialize = "outcome.delete-err")]
    OutcomeDeleteErr,
    #[serde(rename = "outcome.restored")]
    #[strum(serialize = "outcome.restored")]
    OutcomeRestored,
    #[serde(rename = "outcome.trash-emptied")]
    #[strum(serialize = "outcome.trash-emptied")]
    OutcomeTrashEmptied,
    #[serde(rename = "outcome.trash-partial-err")]
    #[strum(serialize = "outcome.trash-partial-err")]
    OutcomeTrashPartialErr,
    #[serde(rename = "outcome.created-archive")]
    #[strum(serialize = "outcome.created-archive")]
    OutcomeCreatedArchive,
    #[serde(rename = "outcome.archive-create-err")]
    #[strum(serialize = "outcome.archive-create-err")]
    OutcomeArchiveCreateErr,
    #[serde(rename = "outcome.extracted")]
    #[strum(serialize = "outcome.extracted")]
    OutcomeExtracted,
    #[serde(rename = "outcome.extracted-partly")]
    #[strum(serialize = "outcome.extracted-partly")]
    OutcomeExtractedPartly,
    #[serde(rename = "outcome.extract-err")]
    #[strum(serialize = "outcome.extract-err")]
    OutcomeExtractErr,
    #[serde(rename = "outcome.mtp-created")]
    #[strum(serialize = "outcome.mtp-created")]
    OutcomeMtpCreated,
    #[serde(rename = "outcome.mtp-renamed")]
    #[strum(serialize = "outcome.mtp-renamed")]
    OutcomeMtpRenamed,
    #[serde(rename = "outcome.moved")]
    #[strum(serialize = "outcome.moved")]
    OutcomeMoved,
    #[serde(rename = "outcome.copied")]
    #[strum(serialize = "outcome.copied")]
    OutcomeCopied,
    #[serde(rename = "outcome.linked")]
    #[strum(serialize = "outcome.linked")]
    OutcomeLinked,
    #[serde(rename = "outcome.transfer-failed")]
    #[strum(serialize = "outcome.transfer-failed")]
    OutcomeTransferFailed,
    #[serde(rename = "pane.error-permission")]
    #[strum(serialize = "pane.error-permission")]
    PaneErrorPermission,
    #[serde(rename = "pane.error-notfound")]
    #[strum(serialize = "pane.error-notfound")]
    PaneErrorNotfound,
    #[serde(rename = "archive.error-password")]
    #[strum(serialize = "archive.error-password")]
    ArchiveErrorPassword,
    #[serde(rename = "archive.error-missing-tool")]
    #[strum(serialize = "archive.error-missing-tool")]
    ArchiveErrorMissingTool,
    #[serde(rename = "archive.error-cancelled")]
    #[strum(serialize = "archive.error-cancelled")]
    ArchiveErrorCancelled,
    #[serde(rename = "archive.error-empty")]
    #[strum(serialize = "archive.error-empty")]
    ArchiveErrorEmpty,
    #[serde(rename = "archive.error-not-archive")]
    #[strum(serialize = "archive.error-not-archive")]
    ArchiveErrorNotArchive,
    #[serde(rename = "archive.error-not-found")]
    #[strum(serialize = "archive.error-not-found")]
    ArchiveErrorNotFound,
    #[serde(rename = "share.error-tool-missing")]
    #[strum(serialize = "share.error-tool-missing")]
    ShareErrorToolMissing,
    #[serde(rename = "share.error-download-failed")]
    #[strum(serialize = "share.error-download-failed")]
    ShareErrorDownloadFailed,
    #[serde(rename = "share.error-no-files")]
    #[strum(serialize = "share.error-no-files")]
    ShareErrorNoFiles,
    #[serde(rename = "share.error-cloudflared-missing")]
    #[strum(serialize = "share.error-cloudflared-missing")]
    ShareErrorCloudflaredMissing,
    #[serde(rename = "share.error-no-url")]
    #[strum(serialize = "share.error-no-url")]
    ShareErrorNoUrl,
    #[serde(rename = "share.error-timeout")]
    #[strum(serialize = "share.error-timeout")]
    ShareErrorTimeout,
    #[serde(rename = "trash.error-no-usable")]
    #[strum(serialize = "trash.error-no-usable")]
    TrashErrorNoUsable,
    #[serde(rename = "trash.error-already")]
    #[strum(serialize = "trash.error-already")]
    TrashErrorAlready,
    #[serde(rename = "trash.error-unsafe")]
    #[strum(serialize = "trash.error-unsafe")]
    TrashErrorUnsafe,
    #[serde(rename = "list.join")]
    #[strum(serialize = "list.join")]
    ListJoin,
    #[serde(rename = "outcome.restore-failed")]
    #[strum(serialize = "outcome.restore-failed")]
    OutcomeRestoreFailed,
    #[serde(rename = "outcome.restore-no-record")]
    #[strum(serialize = "outcome.restore-no-record")]
    OutcomeRestoreNoRecord,
    #[serde(rename = "outcome.restore-item-failed")]
    #[strum(serialize = "outcome.restore-item-failed")]
    OutcomeRestoreItemFailed,
    #[serde(rename = "outcome.item-failed")]
    #[strum(serialize = "outcome.item-failed")]
    OutcomeItemFailed,
    #[serde(rename = "outcome.archive-create-failed")]
    #[strum(serialize = "outcome.archive-create-failed")]
    OutcomeArchiveCreateFailed,
    #[serde(rename = "outcome.rename-duplicate")]
    #[strum(serialize = "outcome.rename-duplicate")]
    OutcomeRenameDuplicate,
    #[serde(rename = "outcome.rename-exists")]
    #[strum(serialize = "outcome.rename-exists")]
    OutcomeRenameExists,
    #[serde(rename = "outcome.rename-no-parent")]
    #[strum(serialize = "outcome.rename-no-parent")]
    OutcomeRenameNoParent,
    #[serde(rename = "outcome.rename-invalid-list")]
    #[strum(serialize = "outcome.rename-invalid-list")]
    OutcomeRenameInvalidList,
    #[serde(rename = "outcome.exists-again")]
    #[strum(serialize = "outcome.exists-again")]
    OutcomeExistsAgain,
    #[serde(rename = "notify.undoing")]
    #[strum(serialize = "notify.undoing")]
    NotifyUndoing,
    #[serde(rename = "notify.redoing")]
    #[strum(serialize = "notify.redoing")]
    NotifyRedoing,
    #[serde(rename = "notify.undone")]
    #[strum(serialize = "notify.undone")]
    NotifyUndone,
    #[serde(rename = "notify.redone")]
    #[strum(serialize = "notify.redone")]
    NotifyRedone,
    #[serde(rename = "notify.undo-failed")]
    #[strum(serialize = "notify.undo-failed")]
    NotifyUndoFailed,
    #[serde(rename = "notify.redo-failed")]
    #[strum(serialize = "notify.redo-failed")]
    NotifyRedoFailed,
    #[serde(rename = "op.mounting")]
    #[strum(serialize = "op.mounting")]
    OpMounting,
    #[serde(rename = "op.unmounting")]
    #[strum(serialize = "op.unmounting")]
    OpUnmounting,
    #[serde(rename = "op.ejecting")]
    #[strum(serialize = "op.ejecting")]
    OpEjecting,
    #[serde(rename = "op.unlocking")]
    #[strum(serialize = "op.unlocking")]
    OpUnlocking,
    #[serde(rename = "op.locking")]
    #[strum(serialize = "op.locking")]
    OpLocking,
    #[serde(rename = "op.renaming-drive")]
    #[strum(serialize = "op.renaming-drive")]
    OpRenamingDrive,
    #[serde(rename = "outcome.restored-renamed")]
    #[strum(serialize = "outcome.restored-renamed")]
    OutcomeRestoredRenamed,
    #[serde(rename = "outcome.restore-failed-renamed")]
    #[strum(serialize = "outcome.restore-failed-renamed")]
    OutcomeRestoreFailedRenamed,
    #[serde(rename = "outcome.transferred-skipped")]
    #[strum(serialize = "outcome.transferred-skipped")]
    OutcomeTransferredSkipped,
    #[serde(rename = "outcome.skipped-only")]
    #[strum(serialize = "outcome.skipped-only")]
    OutcomeSkippedOnly,
    #[serde(rename = "outcome.inside-itself")]
    #[strum(serialize = "outcome.inside-itself")]
    OutcomeInsideItself,
    #[serde(rename = "network.error-gio-missing")]
    #[strum(serialize = "network.error-gio-missing")]
    NetworkErrorGioMissing,
    #[serde(rename = "network.error-mount-failed")]
    #[strum(serialize = "network.error-mount-failed")]
    NetworkErrorMountFailed,
    #[serde(rename = "network.error-folder-not-found")]
    #[strum(serialize = "network.error-folder-not-found")]
    NetworkErrorFolderNotFound,
    #[serde(rename = "drive.error-block-only")]
    #[strum(serialize = "drive.error-block-only")]
    DriveErrorBlockOnly,
    #[serde(rename = "drive.error-udisks-missing")]
    #[strum(serialize = "drive.error-udisks-missing")]
    DriveErrorUdisksMissing,
    #[serde(rename = "drive.error-udisks-failed")]
    #[strum(serialize = "drive.error-udisks-failed")]
    DriveErrorUdisksFailed,
    #[serde(rename = "drive.error-no-mountpoint")]
    #[strum(serialize = "drive.error-no-mountpoint")]
    DriveErrorNoMountpoint,
    #[serde(rename = "drive.error-rename-block-only")]
    #[strum(serialize = "drive.error-rename-block-only")]
    DriveErrorRenameBlockOnly,
    #[serde(rename = "drive.error-gdbus-missing")]
    #[strum(serialize = "drive.error-gdbus-missing")]
    DriveErrorGdbusMissing,
    #[serde(rename = "drive.error-rename-failed")]
    #[strum(serialize = "drive.error-rename-failed")]
    DriveErrorRenameFailed,
    #[serde(rename = "drive.mtp-device")]
    #[strum(serialize = "drive.mtp-device")]
    DriveMtpDevice,
    #[serde(rename = "outcome.drive-ejected")]
    #[strum(serialize = "outcome.drive-ejected")]
    OutcomeDriveEjected,
    #[serde(rename = "outcome.redo-not-in-trash")]
    #[strum(serialize = "outcome.redo-not-in-trash")]
    OutcomeRedoNotInTrash,
    #[serde(rename = "outcome.verb-moved")]
    #[strum(serialize = "outcome.verb-moved")]
    OutcomeVerbMoved,
    #[serde(rename = "outcome.verb-linked")]
    #[strum(serialize = "outcome.verb-linked")]
    OutcomeVerbLinked,
    #[serde(rename = "outcome.verb-copied")]
    #[strum(serialize = "outcome.verb-copied")]
    OutcomeVerbCopied,
    #[serde(rename = "op.detail-progress")]
    #[strum(serialize = "op.detail-progress")]
    OpDetailProgress,
    #[serde(rename = "op.writing-drive")]
    #[strum(serialize = "op.writing-drive")]
    OpWritingDrive,
    #[serde(rename = "share.error-install-in-progress")]
    #[strum(serialize = "share.error-install-in-progress")]
    ShareErrorInstallInProgress,
    #[serde(rename = "share.error-create-bin-dir")]
    #[strum(serialize = "share.error-create-bin-dir")]
    ShareErrorCreateBinDir,
    #[serde(rename = "share.error-unsupported-arch")]
    #[strum(serialize = "share.error-unsupported-arch")]
    ShareErrorUnsupportedArch,
    #[serde(rename = "share.error-move-binary")]
    #[strum(serialize = "share.error-move-binary")]
    ShareErrorMoveBinary,
    #[serde(rename = "share.error-compression-failed")]
    #[strum(serialize = "share.error-compression-failed")]
    ShareErrorCompressionFailed,
    #[serde(rename = "share.error-bind-port")]
    #[strum(serialize = "share.error-bind-port")]
    ShareErrorBindPort,
    #[serde(rename = "share.error-spawn-cloudflared")]
    #[strum(serialize = "share.error-spawn-cloudflared")]
    ShareErrorSpawnCloudflared,
    #[serde(rename = "share.error-capture-stderr")]
    #[strum(serialize = "share.error-capture-stderr")]
    ShareErrorCaptureStderr,
    #[serde(rename = "archive.error-tool-failed")]
    #[strum(serialize = "archive.error-tool-failed")]
    ArchiveErrorToolFailed,
    #[serde(rename = "archive.error-unsupported-format")]
    #[strum(serialize = "archive.error-unsupported-format")]
    ArchiveErrorUnsupportedFormat,
    #[serde(rename = "notify.no-terminal")]
    #[strum(serialize = "notify.no-terminal")]
    NotifyNoTerminal,
    #[serde(rename = "notify.empty-exec")]
    #[strum(serialize = "notify.empty-exec")]
    NotifyEmptyExec,
    #[serde(rename = "fsops.error-copy-into-self")]
    #[strum(serialize = "fsops.error-copy-into-self")]
    FsopsErrorCopyIntoSelf,
    #[serde(rename = "fsops.error-move-into-self")]
    #[strum(serialize = "fsops.error-move-into-self")]
    FsopsErrorMoveIntoSelf,
    #[serde(rename = "fsops.error-dest-exists")]
    #[strum(serialize = "fsops.error-dest-exists")]
    FsopsErrorDestExists,
    #[serde(rename = "fsops.error-overlap")]
    #[strum(serialize = "fsops.error-overlap")]
    FsopsErrorOverlap,
    #[serde(rename = "fsops.error-same-item")]
    #[strum(serialize = "fsops.error-same-item")]
    FsopsErrorSameItem,
    #[serde(rename = "trash.error-no-filename")]
    #[strum(serialize = "trash.error-no-filename")]
    TrashErrorNoFilename,
    #[serde(rename = "trash.error-no-mountpoint")]
    #[strum(serialize = "trash.error-no-mountpoint")]
    TrashErrorNoMountpoint,
    #[serde(rename = "undo.trash")]
    #[strum(serialize = "undo.trash")]
    UndoTrash,
    #[serde(rename = "undo.compress")]
    #[strum(serialize = "undo.compress")]
    UndoCompress,
    #[serde(rename = "undo.extract")]
    #[strum(serialize = "undo.extract")]
    UndoExtract,
    #[serde(rename = "undo.new-folder")]
    #[strum(serialize = "undo.new-folder")]
    UndoNewFolder,
    #[serde(rename = "undo.new-file")]
    #[strum(serialize = "undo.new-file")]
    UndoNewFile,
    #[serde(rename = "undo.new-document")]
    #[strum(serialize = "undo.new-document")]
    UndoNewDocument,
    #[serde(rename = "undo.rename")]
    #[strum(serialize = "undo.rename")]
    UndoRename,
    #[serde(rename = "undo.move")]
    #[strum(serialize = "undo.move")]
    UndoMove,
    #[serde(rename = "undo.link")]
    #[strum(serialize = "undo.link")]
    UndoLink,
    #[serde(rename = "undo.copy")]
    #[strum(serialize = "undo.copy")]
    UndoCopy,
    #[serde(rename = "mtp.error-parse-response")]
    #[strum(serialize = "mtp.error-parse-response")]
    MtpErrorParseResponse,
    #[serde(rename = "mtp.error-missing-entries")]
    #[strum(serialize = "mtp.error-missing-entries")]
    MtpErrorMissingEntries,
    #[serde(rename = "mtp.error-invalid-filename")]
    #[strum(serialize = "mtp.error-invalid-filename")]
    MtpErrorInvalidFilename,
    #[serde(rename = "mtp.error-invalid-url")]
    #[strum(serialize = "mtp.error-invalid-url")]
    MtpErrorInvalidUrl,
    #[serde(rename = "mtp.error-root-mkdir")]
    #[strum(serialize = "mtp.error-root-mkdir")]
    MtpErrorRootMkdir,
    #[serde(rename = "mtp.error-invalid-dir-name")]
    #[strum(serialize = "mtp.error-invalid-dir-name")]
    MtpErrorInvalidDirName,
    #[serde(rename = "mtp.error-mkdir-failed")]
    #[strum(serialize = "mtp.error-mkdir-failed")]
    MtpErrorMkdirFailed,
    #[serde(rename = "mtp.error-root-rename")]
    #[strum(serialize = "mtp.error-root-rename")]
    MtpErrorRootRename,
    #[serde(rename = "mtp.error-no-parent")]
    #[strum(serialize = "mtp.error-no-parent")]
    MtpErrorNoParent,
    #[serde(rename = "mtp.error-invalid-rename")]
    #[strum(serialize = "mtp.error-invalid-rename")]
    MtpErrorInvalidRename,
    #[serde(rename = "mtp.error-already-exists")]
    #[strum(serialize = "mtp.error-already-exists")]
    MtpErrorAlreadyExists,
    #[serde(rename = "mtp.error-rename-failed")]
    #[strum(serialize = "mtp.error-rename-failed")]
    MtpErrorRenameFailed,
    #[serde(rename = "mtp.error-root-delete")]
    #[strum(serialize = "mtp.error-root-delete")]
    MtpErrorRootDelete,
    #[serde(rename = "mtp.error-delete-failed")]
    #[strum(serialize = "mtp.error-delete-failed")]
    MtpErrorDeleteFailed,
    #[serde(rename = "mtp.error-root-download")]
    #[strum(serialize = "mtp.error-root-download")]
    MtpErrorRootDownload,
    #[serde(rename = "mtp.error-file-not-found")]
    #[strum(serialize = "mtp.error-file-not-found")]
    MtpErrorFileNotFound,
    #[serde(rename = "mtp.error-dir-single-download")]
    #[strum(serialize = "mtp.error-dir-single-download")]
    MtpErrorDirSingleDownload,
    #[serde(rename = "mtp.error-invalid-utf8")]
    #[strum(serialize = "mtp.error-invalid-utf8")]
    MtpErrorInvalidUtf8,
    #[serde(rename = "mtp.error-download-failed")]
    #[strum(serialize = "mtp.error-download-failed")]
    MtpErrorDownloadFailed,
    #[serde(rename = "mtp.error-download-size")]
    #[strum(serialize = "mtp.error-download-size")]
    MtpErrorDownloadSize,
    #[serde(rename = "mtp.error-source-disappeared")]
    #[strum(serialize = "mtp.error-source-disappeared")]
    MtpErrorSourceDisappeared,
    #[serde(rename = "mtp.error-cancelled-preserved")]
    #[strum(serialize = "mtp.error-cancelled-preserved")]
    MtpErrorCancelledPreserved,
    #[serde(rename = "mtp.error-unsupported-type")]
    #[strum(serialize = "mtp.error-unsupported-type")]
    MtpErrorUnsupportedType,
    #[serde(rename = "mtp.error-source-changed")]
    #[strum(serialize = "mtp.error-source-changed")]
    MtpErrorSourceChanged,
    #[serde(rename = "mtp.error-not-mtp-path")]
    #[strum(serialize = "mtp.error-not-mtp-path")]
    MtpErrorNotMtpPath,
    #[serde(rename = "mtp.error-no-links")]
    #[strum(serialize = "mtp.error-no-links")]
    MtpErrorNoLinks,
    #[serde(rename = "mtp.error-root-transfer")]
    #[strum(serialize = "mtp.error-root-transfer")]
    MtpErrorRootTransfer,
    #[serde(rename = "mtp.error-stat-source")]
    #[strum(serialize = "mtp.error-stat-source")]
    MtpErrorStatSource,
    #[serde(rename = "mtp.error-cleanup-source")]
    #[strum(serialize = "mtp.error-cleanup-source")]
    MtpErrorCleanupSource,
    #[serde(rename = "mtp.error-dest-not-dir")]
    #[strum(serialize = "mtp.error-dest-not-dir")]
    MtpErrorDestNotDir,
    #[serde(rename = "mtp.error-copy-into-self")]
    #[strum(serialize = "mtp.error-copy-into-self")]
    MtpErrorCopyIntoSelf,
    #[serde(rename = "mtp.error-upload-failed")]
    #[strum(serialize = "mtp.error-upload-failed")]
    MtpErrorUploadFailed,
    #[serde(rename = "mtp.error-upload-verify")]
    #[strum(serialize = "mtp.error-upload-verify")]
    MtpErrorUploadVerify,
    #[serde(rename = "mtp.error-read-dir")]
    #[strum(serialize = "mtp.error-read-dir")]
    MtpErrorReadDir,
    #[serde(rename = "mtp.error-download-incomplete")]
    #[strum(serialize = "mtp.error-download-incomplete")]
    MtpErrorDownloadIncomplete,
    #[serde(rename = "mtp.error-create-local-dir")]
    #[strum(serialize = "mtp.error-create-local-dir")]
    MtpErrorCreateLocalDir,
}

/// A user-visible message: either a localized key with arguments, or raw user text.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Message {
    pub(crate) v: u8,
    pub(crate) body: MessageBody,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum MessageBody {
    Key {
        key: MessageKey,
        args: Vec<MessageArgument>,
    },
    Raw {
        raw: String,
    },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum MessageArgument {
    Text(String),
    Count(usize),
    Nested(Box<Message>),
}

impl Message {
    /// Creates a localized message from a `MessageKey`.
    pub fn key(key: MessageKey) -> Self {
        Message {
            v: 1,
            body: MessageBody::Key {
                key,
                args: Vec::new(),
            },
        }
    }

    /// Wraps user-controlled text so QML shows it literally, never resolving it as a key.
    pub fn raw(text: impl Into<String>) -> Self {
        Message {
            v: 1,
            body: MessageBody::Raw { raw: text.into() },
        }
    }

    /// Appends a plain text argument to a key-based message.
    pub fn text(mut self, text: impl Into<String>) -> Self {
        if let MessageBody::Key { ref mut args, .. } = self.body {
            args.push(MessageArgument::Text(text.into()));
        }
        self
    }

    /// Appends a numeric count argument to a key-based message.
    pub fn count(mut self, count: usize) -> Self {
        if let MessageBody::Key { ref mut args, .. } = self.body {
            args.push(MessageArgument::Count(count));
        }
        self
    }

    /// Appends a nested `Message` argument to a key-based message.
    pub fn nested(mut self, nested: Message) -> Self {
        if let MessageBody::Key { ref mut args, .. } = self.body {
            args.push(MessageArgument::Nested(Box::new(nested)));
        }
        self
    }

    /// Serializes several messages joined with "; " in QML using `MessageKey::ListJoin`.
    pub fn list(items: impl IntoIterator<Item = Message>) -> Self {
        let mut msg = Message::key(MessageKey::ListJoin);
        for item in items {
            msg = msg.nested(item);
        }
        msg
    }

    /// Convenience for building string representation directly.
    pub fn to_json_string(&self) -> String {
        serde_json::to_string(self).unwrap_or_else(|_| "{}".to_string())
    }
}

impl fmt::Display for Message {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let json = serde_json::to_string(self).map_err(|_| fmt::Error)?;
        write!(f, "{json}")
    }
}

impl From<Message> for String {
    fn from(m: Message) -> Self {
        m.to_string()
    }
}

impl Serialize for Message {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        use serde::ser::SerializeMap;
        match &self.body {
            MessageBody::Key { key, args } => {
                let len = if args.is_empty() { 2 } else { 3 };
                let mut map = serializer.serialize_map(Some(len))?;
                if !args.is_empty() {
                    map.serialize_entry("args", args)?;
                }
                map.serialize_entry("key", key)?;
                map.serialize_entry("v", &self.v)?;
                map.end()
            }
            MessageBody::Raw { raw } => {
                let mut map = serializer.serialize_map(Some(2))?;
                map.serialize_entry("raw", raw)?;
                map.serialize_entry("v", &self.v)?;
                map.end()
            }
        }
    }
}

impl Serialize for MessageArgument {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        match self {
            MessageArgument::Text(s) => serializer.serialize_str(s),
            MessageArgument::Count(c) => serializer.serialize_str(&c.to_string()),
            MessageArgument::Nested(m) => m.serialize(serializer),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::BTreeSet;
    use std::path::PathBuf;
    use strum::IntoEnumIterator;

    #[test]
    fn rust_message_keys_match_qml_messages() {
        let rust_keys: BTreeSet<String> = MessageKey::iter()
            .map(|k| {
                serde_json::to_string(&k)
                    .unwrap()
                    .trim_matches('"')
                    .to_string()
            })
            .collect();

        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
        let qml_source =
            std::fs::read_to_string(root.join("qml/Messages.qml")).expect("qml/Messages.qml");

        let mut qml_keys = BTreeSet::new();
        for line in qml_source.lines() {
            let line = line.trim();
            if let Some(rest) = line.strip_prefix("case \"") {
                if let Some(key) = rest.split('"').next() {
                    qml_keys.insert(key.to_string());
                }
            }
        }

        let only_rust: Vec<&String> = rust_keys.difference(&qml_keys).collect();
        let only_qml: Vec<&String> = qml_keys.difference(&rust_keys).collect();

        assert!(
            only_rust.is_empty() && only_qml.is_empty(),
            "message key mismatch\nRust-only keys: {:?}\nQML-only keys: {:?}",
            only_rust,
            only_qml
        );
    }
}
