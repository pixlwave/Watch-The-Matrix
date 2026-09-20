import Matrix

extension MatrixError: @retroactive Identifiable {
    // add an Identifiable conformance for use as a sheet item
    // for the purposes of an information sheet, the error's
    // description will be fine as an identifier
    public var id: String { description }
}
