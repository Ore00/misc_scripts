# Misc Scripts

This repository contains a collection of **Python** and **Shell** scripts designed to run locally from the terminal.  
The scripts cover multiple use cases such as:

- PC Security monitoring (connections, processes, logs)  
- Job scraping & career research  
- General daily automation tasks 

All scripts are lightweight and run **locally** without external dependencies (unless otherwise noted).  

---

## Project Structure

```
├── README.md
├── logs/
├── output/
│── daily_job_matcher.sh    # Run scraper & save results to log
│── job_scraper.py          # Scrape job postings from selected sites
│── sys_watcher.py          # Monitor suspicious processes
│── system_watcher.py       # Check logs for unusual activity
```

---

## Getting Started

### 1. Clone the Repository
```bash
git clone https://github.com/ore00/misc_scripts.git
cd misc_scripts
```

### 2. Requirements
- **Python 3.8+**  
- **Bash / Zsh (macOS & Linux)**  
- Recommended: `pip install -r requirements.txt` if included

### 3. Running Scripts

#### Security Monitoring
```bash
# Monitor active connections
python3 sys_watcher.py

# Audit suspicious processes
python3 system_watcher.sh
```

#### Job Scraping
```bash
# Run daily scraper
python3 job_scraper.py

# Or use wrapper shell script
python3 daily_job_matcher.py
```

---

## Automation

To run scripts daily, set up a **cron job** (Linux/macOS):

```bash
crontab -e
```

Example: Run job scraper at 8 AM every day:
```
0 8 * * * /usr/bin/python3 /path/to/jobs/job_scraper.py >> /path/to/logs/job_scraper.log 2>&1
```

---

## Logs

All scripts can be configured to log output.  
Example log locations:
```
logs/security.log
logs/jobs.log
```

---

## Disclaimer

These scripts are for **personal use and educational purposes only**.  
- Security scripts are **not a replacement** for enterprise security tools.  
- Job scraping scripts must follow each site’s **Terms of Service**.  

Use responsibly.  

---

## 🛠️ Roadmap
- [ ] Add email notifications for job results  
- [ ] Extend PC Security to include malware signature checks  
- [ ] Build dashboard UI for viewing logs & results  

---

## Contributing
Contributions are welcome!  
- Fork the repo  
- Create a new branch (`feature/my-feature`)  
- Submit a pull request  

---