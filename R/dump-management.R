### =========================================================================
### HDF5 dump management
### -------------------------------------------------------------------------
###


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### 2 global internal counters: one for the dump files, one for the dump
### names
###
### The 2 counters are safe to use in the context of parallel execution e.g.
###
###   library(BiocParallel)
###   bplapply(1:5, function(i) .get_dump_files_global_counter(increment=TRUE))
###   bplapply(1:5, function(i) .get_dump_names_global_counter(increment=TRUE))
###

.get_dump_files_global_counter_filepath <- function()
{
    file.path(tempdir(), "HDF5Array_dump_files_global_counter")
}
 
.get_dump_names_global_counter_filepath <- function()
{
    file.path(tempdir(), "HDF5Array_dump_names_global_counter")
}

### Called by .onLoad() hook (see zzz.R file). 
init_HDF5_dump_files_global_counter <- function()
{
    filepath <- .get_dump_files_global_counter_filepath()
    init_global_counter(filepath)
}

### Called by .onLoad() hook (see zzz.R file).
init_HDF5_dump_names_global_counter <- function()
{
    filepath <- .get_dump_names_global_counter_filepath()
    init_global_counter(filepath)
}

.get_dump_files_global_counter <- function(increment=FALSE)
{
    filepath <- .get_dump_files_global_counter_filepath()
    get_global_counter(filepath, increment=increment)
}

.get_dump_names_global_counter <- function(increment=FALSE)
{
    filepath <- .get_dump_names_global_counter_filepath()
    get_global_counter(filepath, increment=increment)
}


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Very low-level stuff
###

.dump_settings_envir <- new.env(parent=emptyenv())

.set_dump_dir <- function(dir)
{
    if (!dir.exists(dir)) {
        if (file.exists(dir))
            stop(wmsg("\"", dir, "\" already exists and is a file, ",
                      "not a directory"))
        if (!suppressWarnings(dir.create(dir)))
            stop("cannot create directory \"", dir, "\"")
    }
    dir <- file_path_as_absolute(dir)
    assign("dir", dir, envir=.dump_settings_envir)
}

.get_dump_dir <- function()
{
    dir <- try(get("dir", envir=.dump_settings_envir), silent=TRUE)
    if (is(dir, "try-error")) {
        dir <- file.path(tempdir(), "HDF5Array_dump")
        .set_dump_dir(dir)
    }
    dir
}

.set_dump_autofiles_mode <- function()
{
    suppressWarnings(rm(list="specfile", envir=.dump_settings_envir))
}

.get_dump_autofile <- function(increment=FALSE)
{
    counter <- .get_dump_files_global_counter(increment=increment)
    file <- file.path(.get_dump_dir(), sprintf("auto%05d.h5", counter))
    if (!file.exists(file))
        h5createFile(file)
    file
}

.set_dump_specfile <- function(file)
{
    file <- file_path_as_absolute(file)
    assign("specfile", file, envir=.dump_settings_envir)
}

### Return the user-specified file of the dump or an error if the user didn't
### specify a file.
.get_dump_specfile <- function()
{
    get("specfile", envir=.dump_settings_envir)
}

.set_dump_autonames_mode <- function()
{
    suppressWarnings(rm(list="specname", envir=.dump_settings_envir))
}

.get_dump_autoname <- function(increment=FALSE)
{
    counter <- .get_dump_names_global_counter(increment=increment)
    sprintf("/HDF5ArrayAUTO%05d", counter)
}

.set_dump_specname <- function(name)
{
    assign("specname", name, envir=.dump_settings_envir)
}

### Return the user-specified name of the dump or an error if the user didn't
### specify a name.
.get_dump_specname <- function()
{
    get("specname", envir=.dump_settings_envir)
}


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### set/getHDF5DumpFile()
###

check_dump_file <- function(file)
{
    if (!isSingleString(file) || file == "")
        stop(wmsg("'file' must be a single string specifying the path ",
                  "to a new or existing HDF5 file"))
    if (file.exists(file))
        return(h5ls(file))
    h5createFile(file)
    return(NULL)
}

### Called by .onLoad() hook (see zzz.R file).
setHDF5DumpFile <- function(file)
{
    if (missing(file)) {
        .set_dump_autofiles_mode()
        file <- .get_dump_autofile()
        file_content <- check_dump_file(file)
    } else {
        if (!isSingleString(file) || file == "")
            stop("'file' must be a single non-empty string")
        nc <- nchar(file)
        if (substr(file, start=nc, stop=nc) == "/") {
            if (nc >= 2L)
                file <- substr(file, start=1L, stop=nc-1L)
            .set_dump_dir(file)
            file <- .get_dump_autofile()
            file_content <- check_dump_file(file)
        } else {
            file_content <- check_dump_file(file)
            .set_dump_specfile(file)
        }
    }
    if (is.null(file_content))
        return(invisible(file_content))
    file_content
}

### Return the *absolute path* to the dump file.
getHDF5DumpFile <- function()
{
    file <- try(.get_dump_specfile(), silent=TRUE)
    if (is(file, "try-error"))
        file <- .get_dump_autofile()
    file
}

get_dump_file_for_use <- function()
{
    file <- try(.get_dump_specfile(), silent=TRUE)
    if (is(file, "try-error"))
        file <- .get_dump_autofile(increment=TRUE)
    file
}

### A convenience wrapper.
lsHDF5DumpFile <- function() h5ls(getHDF5DumpFile())


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### set/getHDF5DumpName()
###

check_dump_name <- function(name)
{
    if (!isSingleString(name))
        stop(wmsg("'name' must be a single string specifying the name ",
                  "of the HDF5 dataset to write"))
    if (name == "")
        stop(wmsg("'name' cannot be the empty string"))
}

setHDF5DumpName <- function(name)
{
    if (missing(name)) {
        .set_dump_autonames_mode()
        name <- .get_dump_autoname()
        return(invisible(name))
    }
    check_dump_name(name)
    .set_dump_specname(name)
}

getHDF5DumpName <- function()
{
    name <- try(.get_dump_specname(), silent=TRUE)
    if (is(name, "try-error"))
        name <- .get_dump_autoname()
    name
}

get_dump_name_for_use <- function()
{
    name <- try(.get_dump_specname(), silent=TRUE)
    if (is(name, "try-error")) {
        name <- .get_dump_autoname(increment=TRUE)
    } else {
        ## If the dump file is a user-specified file, we switch back to
        ## automatic dump names.
        file <- try(.get_dump_specfile(), silent=TRUE)
        if (!is(file, "try-error"))
            .set_dump_autonames_mode()
    }
    name
}


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Dump log
###

### Called by .onLoad() hook (see zzz.R file).
get_HDF5_dump_logfile <- function()
{
    file.path(tempdir(), "HDF5Array_dump_log")
}

.get_dataset_creation_global_counter_filepath <- function()
{
    file.path(tempdir(), "HDF5Array_dataset_creation_global_counter")
}

### Called by .onLoad() hook (see zzz.R file). 
init_HDF5_dataset_creation_global_counter <- function()
{
    filepath <- .get_dataset_creation_global_counter_filepath()
    init_global_counter(filepath)
}

.get_dataset_creation_global_counter <- function(increment=FALSE)
{
    filepath <- .get_dataset_creation_global_counter_filepath()
    get_global_counter(filepath, increment=increment)
}

### Use a lock mechanism so is safe to use in the context of parallel
### execution.
append_dataset_creation_to_dump_logfile <- function(file, name, dim, type)
{
    logfile <- get_HDF5_dump_logfile()
    locked_path <- lock_file(logfile)
    on.exit(unlock_file(logfile))
    counter <- .get_dataset_creation_global_counter(increment=TRUE)
    dim_in1string <- paste0(dim, collapse="x")
    cat("[", as.character(Sys.time()), "] #", counter, " ",
        "Dataset '", name, "' (", dim_in1string, ":", type, ") ",
        "created in file '", file, "'\n",
        file=locked_path, sep="", append=TRUE)
}

showHDF5DumpLog <- function()
{
    cat(readLines(get_HDF5_dump_logfile()), sep="\n")
}
