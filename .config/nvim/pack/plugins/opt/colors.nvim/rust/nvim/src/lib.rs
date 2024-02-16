use std::os::raw::*;

pub struct Server;

#[repr(transparent)]
pub struct Row(pub c_int);

#[repr(transparent)]
pub struct BufferId(pub c_int);

#[repr(transparent)]
pub struct Buffer<'a>(&'a c_void);

impl Buffer<'_> {
    /// # Safety
    ///
    /// - Buffer pointer is valid.
    ///
    /// - Returned slice is dropped before `ml_get_buf` would invalidate the internal pointer.
    /// Refer to NeoVim internals.
    pub unsafe fn get_line(&self, row: Row) -> &[u8] {
        extern "C" {
            pub fn ml_get_buf(_: *const c_void, _: i32) -> *const u8;
            pub fn strlen(_: *const u8) -> usize;
        }

        let ptr = ml_get_buf(self.0, row.0);
        std::slice::from_raw_parts(ptr, strlen(ptr) + 1)
    }
}

#[allow(clippy::new_without_default)]
impl Server {
    pub fn new() -> Self {
        Self
    }

    pub fn get_buffer(&self, handle: BufferId) -> Option<Buffer> {
        extern "C" {
            pub fn buflist_findnr(_: c_int) -> *const c_void;
        }

        unsafe { buflist_findnr(handle.0).as_ref() }.map(Buffer)
    }
}
