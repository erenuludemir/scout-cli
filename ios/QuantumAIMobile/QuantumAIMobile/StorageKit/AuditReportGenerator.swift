import Foundation

public final class AuditReportGenerator {
    public static func generateJSON(records: [AuditRecord]) -> Data? {
        try? JSONEncoder().encode(records)
    }

    public static func generateCSV(records: [AuditRecord]) -> String {
        var csv = "ID,Timestamp,Action,Actor,Hash\n"
        for r in records {
            csv += "\(r.id),\(r.ts),\(r.action),\(r.actor),\(r.payloadHash)\n"
        }
        return csv
    }
}
