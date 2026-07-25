use hdk::prelude::*;

#[hdk_extern]
pub fn signal_test_handshake(_: ()) -> ExternResult<String> {
    Ok(String::from("Connection to hc_deepid successful!"))
}
