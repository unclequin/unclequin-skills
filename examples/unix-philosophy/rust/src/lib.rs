//! The code shown in skills/unix-philosophy/references/languages/rust.md.
//! scripts/check-examples.py checks that the two stay the same.

use std::fmt;
use std::future::Future;
use std::time::Duration;

use std::io::{self, BufRead};

use anyhow::Context;

pub struct Signup {
    pub email: String,
}

pub struct User {
    pub email: String,
}

#[derive(Debug)]
pub struct ValidationError(String);

impl fmt::Display for ValidationError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "not an email address: {}", self.0)
    }
}

impl std::error::Error for ValidationError {}

pub fn parse_signup(body: &str) -> Result<Signup, ValidationError> {
    if body.contains('@') {
        Ok(Signup {
            email: body.to_string(),
        })
    } else {
        Err(ValidationError(body.to_string()))
    }
}

pub struct Users;

impl Users {
    pub async fn create(&self, signup: &Signup) -> anyhow::Result<User> {
        Ok(User {
            email: signup.email.clone(),
        })
    }
}

#[derive(Default)]
pub struct Mailer {
    pub welcomed: std::cell::RefCell<Vec<String>>,
}

impl Mailer {
    pub async fn send_welcome(&self, user: &User) -> anyhow::Result<()> {
        self.welcomed.borrow_mut().push(user.email.clone());
        Ok(())
    }
}

// rustfmt would pull the trailing comment in; the reference file aligns it.
#[rustfmt::skip]
pub async fn signup(body: String, users: &Users, mailer: &Mailer) -> anyhow::Result<()> {
    // main.rs only wires parts together
    let signup = parse_signup(&body)?;          // -> Result<Signup, ValidationError>
    let user = users.create(&signup).await?;
    mailer.send_welcome(&user).await?;
    Ok(())
}

// Composable: works with stdin, files, sockets, and &[u8] in tests
fn count_lines<R: BufRead>(reader: R) -> io::Result<usize> {
    let mut n = 0;
    for line in reader.lines() {
        line?;
        n += 1;
    }
    Ok(n)
}

pub fn count_stdin_lines() -> io::Result<usize> {
    count_lines(io::stdin().lock())
}

pub struct RetryPolicy {
    pub max_attempts: u32,
    pub backoff: Duration,
}

/// The mechanism the reference file leaves as a comment. A real one awaits
/// the runtime's timer between attempts; this one has no runtime to ask.
pub async fn with_retry<T, E, F, Fut>(policy: &RetryPolicy, mut f: F) -> Result<T, E>
where
    F: FnMut() -> Fut,
    Fut: Future<Output = Result<T, E>>,
{
    let mut attempt = 1;
    loop {
        match f().await {
            Err(_) if attempt < policy.max_attempts => attempt += 1,
            result => return result,
        }
        std::thread::sleep(policy.backoff);
    }
}

pub struct Order {
    pub id: String,
}

pub struct Client;

impl Client {
    pub async fn fetch(&self, order_id: &str) -> io::Result<Order> {
        if order_id == "missing" {
            return Err(io::Error::new(io::ErrorKind::NotFound, "no such order"));
        }
        Ok(Order {
            id: order_id.to_string(),
        })
    }
}

pub async fn fetch_opaque(client: &Client, order_id: &str) -> anyhow::Result<Order> {
    // Opaque
    let order = client.fetch(order_id).await?;
    Ok(order)
}

pub async fn fetch_transparent(client: &Client, order_id: &str) -> anyhow::Result<Order> {
    // Transparent: what failed and on what, original error preserved
    let order = client
        .fetch(order_id)
        .await
        .with_context(|| format!("fetch order {order_id}"))?;
    Ok(order)
}

pub fn port_from_env() -> anyhow::Result<u16> {
    // Fail fast at startup
    let port: u16 = std::env::var("PORT")
        .context("PORT is required")?
        .parse()
        .context("PORT must be a number from 0 to 65535")?;
    Ok(port)
}

/// Version 1 of the quote request.
pub struct QuoteV1 {
    pub sku: String,
    pub quantity: u32,
}

/// Version 2 adds an optional coupon; every `QuoteV1` converts to one with none.
pub struct QuoteV2 {
    pub sku: String,
    pub quantity: u32,
    pub coupon: Option<String>,
}

impl From<QuoteV1> for QuoteV2 {
    fn from(q: QuoteV1) -> Self {
        QuoteV2 {
            sku: q.sku,
            quantity: q.quantity,
            coupon: None,
        }
    }
}

pub const PRICES: &[(&str, u32)] = &[("apple", 100), ("pear", 150)];
const PERCENT_OFF: &[(&str, u32)] = &[("TENOFF", 10)];

fn lookup(table: &[(&str, u32)], key: &str, what: &str) -> anyhow::Result<u32> {
    let found = table.iter().find(|(k, _)| *k == key);
    found
        .map(|(_, value)| *value)
        .ok_or_else(|| anyhow::anyhow!("unknown {what}: {key}"))
}

pub fn quote_v1(q: &QuoteV1) -> anyhow::Result<u32> {
    Ok(lookup(PRICES, &q.sku, "sku")? * q.quantity)
}

pub fn quote_v2(q: &QuoteV2) -> anyhow::Result<u32> {
    let total = lookup(PRICES, &q.sku, "sku")? * q.quantity;
    match &q.coupon {
        None => Ok(total),
        Some(coupon) => Ok(total - total * lookup(PERCENT_OFF, coupon, "coupon")? / 100),
    }
}

// rustfmt would spread these one-line declarations over several lines; the
// reference file shows them compact. Nothing uses the sketch types.
#[rustfmt::skip]
#[allow(dead_code)]
mod compact {
    use anyhow::Result;

    struct User;
    struct PgPool;

    // Over-engineered: a trait with one implementation, plus a boxed factory
    trait UserService { fn get(&self, id: &str) -> Result<User>; /* ...8 more */ }
    struct UserServiceImpl { /* ... */ }

    // Simple: a concrete struct; add a narrow trait when a second implementation
    // or a test double is actually needed
    struct UserStore { pool: PgPool }

    #[derive(Debug, Clone, Copy, PartialEq, Eq)]
    enum Zone { Bkk, Central, North, Other }

    impl Zone {
        fn fee(self) -> u32 {
            match self {
                Zone::Bkk => 40,
                Zone::Central => 60,
                Zone::North => 80,
                Zone::Other => 100,
            }
        }
    }

    #[test]
    fn every_zone_has_its_fee() {
        let fees = [Zone::Bkk, Zone::Central, Zone::North, Zone::Other].map(Zone::fee);
        assert_eq!(fees, [40, 60, 80, 100]);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::pin::pin;
    use std::task::{Context as TaskContext, Poll, Waker};

    /// Enough of an executor for futures that never wait on anything.
    fn block_on<F: Future>(future: F) -> F::Output {
        let mut future = pin!(future);
        let mut cx = TaskContext::from_waker(Waker::noop());
        loop {
            if let Poll::Ready(value) = future.as_mut().poll(&mut cx) {
                return value;
            }
        }
    }

    #[test]
    fn signup_parses_creates_then_mails() {
        let mailer = Mailer::default();
        block_on(signup("a@b.c".to_string(), &Users, &mailer)).unwrap();
        let err = block_on(signup("nobody".to_string(), &Users, &mailer)).unwrap_err();
        assert!(err.is::<ValidationError>());
        assert_eq!(*mailer.welcomed.borrow(), ["a@b.c"]);
    }

    #[test]
    fn count_lines_takes_any_buf_read() {
        // count_lines(io::stdin().lock())
        // count_lines(BufReader::new(File::open(path)?))
        // count_lines(&b"a\nb\n"[..])
        assert_eq!(count_lines(&b"a\nb\n"[..]).unwrap(), 2);
    }

    #[test]
    fn with_retry_gives_up_after_max_attempts() {
        let policy = RetryPolicy {
            max_attempts: 3,
            backoff: Duration::ZERO,
        };
        let mut calls = 0;
        let result: Result<(), &str> = block_on(with_retry(&policy, || {
            calls += 1;
            async { Err("down") }
        }));
        assert_eq!((result, calls), (Err("down"), 3));
    }

    #[test]
    fn transparent_error_keeps_context_and_cause() {
        let opaque = block_on(fetch_opaque(&Client, "missing")).err().unwrap();
        assert_eq!(opaque.to_string(), "no such order");
        let transparent = block_on(fetch_transparent(&Client, "missing"))
            .err()
            .unwrap();
        assert_eq!(transparent.to_string(), "fetch order missing");
        assert_eq!(transparent.root_cause().to_string(), "no such order");
        assert_eq!(block_on(fetch_transparent(&Client, "o1")).unwrap().id, "o1");
    }

    #[test]
    fn port_must_be_present_and_a_number() {
        // One test, because the environment is shared between test threads.
        std::env::remove_var("PORT");
        assert_eq!(port_from_env().unwrap_err().to_string(), "PORT is required");
        std::env::set_var("PORT", "eighty");
        assert_eq!(
            port_from_env().unwrap_err().to_string(),
            "PORT must be a number from 0 to 65535"
        );
        std::env::set_var("PORT", "8080");
        assert_eq!(port_from_env().unwrap(), 8080);
    }

    #[test]
    fn version_2_answers_every_version_1_request_the_same() {
        for (sku, _) in PRICES {
            for quantity in 1..=100 {
                let q = QuoteV1 {
                    sku: sku.to_string(),
                    quantity,
                };
                let expected = quote_v1(&q).unwrap();
                assert_eq!(quote_v2(&q.into()).unwrap(), expected);
            }
        }
    }

    #[test]
    fn version_2s_new_field_changes_only_the_new_requests() {
        let with = |coupon: &str| QuoteV2 {
            sku: "pear".to_string(),
            quantity: 3,
            coupon: Some(coupon.to_string()),
        };
        assert_eq!(quote_v2(&with("TENOFF")).unwrap(), 405);
        let err = quote_v2(&with("BOGUS")).unwrap_err();
        assert_eq!(err.to_string(), "unknown coupon: BOGUS");
    }
}
