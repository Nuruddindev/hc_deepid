use hdi::prelude::*;

pub mod avatar;
pub mod profile;
pub mod user;

// Definisikan struktur entri account utama Anda di sini
#[hdk_entry_helper]
#[serde(rename_all = "camelCase")]
pub struct AccountEntry {
    pub django_account_id: String,
    pub django_public_key: String,
    pub custodian_status: bool,
}

#[hdk_entry_types]
#[unit_enum(UnitEntryTypes)]
pub enum EntryTypes {
    Account(AccountEntry),
}
